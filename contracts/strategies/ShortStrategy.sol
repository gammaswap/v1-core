// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/strategies/base/IShortStrategy.sol";
import "../interfaces/periphery/ISendTokensCallback.sol";
import "./base/BaseStrategy.sol";

/// @title Short Strategy abstract contract implementation of IShortStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that deposit and withdraw liquidity
abstract contract ShortStrategy is IShortStrategy, BaseStrategy {

    error ZeroShares();
    error ZeroAssets();
    error ExcessiveWithdrawal();
    error ExcessiveSpend();
    error InvalidAmountsDesiredLength();
    error InvalidAmountsMinLength();

    /// @dev Error thrown when wrong amount of ERC20 token is deposited in GammaPool
    /// @param token - address of ERC20 token that caused the error
    error WrongTokenBalance(address token);

    // Short Gamma

    /// @dev Minimum number of shares issued on first deposit to avoid rounding issues
    uint256 public constant MIN_SHARES = 1e3;

    /// @notice Calculate amounts to deposit in CFMM depending on the CFMM's formula
    /// @dev The user requests desired amounts to deposit and sets minimum amounts since actual amounts are unknown at time of request
    /// @param amountsDesired - desired amounts of reserve tokens to deposit in CFMM
    /// @param amountsMin - minimum amounts of reserve tokens expected to deposit in CFMM
    /// @return reserves - amounts that will be deposited in CFMM
    /// @return payee - address reserve tokens will be sent to. Address holding CFMM's reserves might be different from CFMM's address
    function calcDepositAmounts(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal virtual view returns (uint256[] memory reserves, address payee);

    /// @inheritdoc IShortStrategy
    function calcUtilRateEma(uint256 utilizationRate, uint256 emaUtilRateLast, uint256 emaMultiplier) external virtual override view returns(uint256 emaUtilRate) {
        return _calcUtilRateEma(utilizationRate, emaUtilRateLast, emaMultiplier);
    }

    /// @inheritdoc IShortStrategy
    function totalAssets(uint256 borrowedInvariant, uint256 lpBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 lastFeeIndex) public virtual override view returns(uint256 lastLPBalance) {
        // Return CFMM LP tokens depositedin GammaPool plus borrowed liquidity invariant with accrued interest in terms of CFMM LP tokens
        (lastLPBalance,,) = getLatestBalances(lastFeeIndex, borrowedInvariant, lpBalance, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    /// @inheritdoc IShortStrategy
    function totalSupply(address factory, address pool, uint256 lastCFMMFeeIndex, uint256 lastFeeIndex, uint256 utilizationRate, uint256 supply) public virtual override view returns (uint256) {
        uint256 devShares = 0;
        (address feeTo, uint256 protocolFee,, ) = IGammaPoolFactory(factory).getPoolFee(pool);
        if(feeTo != address(0)) {
            uint256 printPct = _calcProtocolDilution(lastFeeIndex, lastCFMMFeeIndex, utilizationRate, protocolFee);
            devShares = supply * printPct / 1e18;
        }
        return supply + devShares;
    }

    /// @inheritdoc IShortStrategy
    function getLatestBalances(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lpBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual override view
        returns(uint256 lastLPBalance, uint256 lastBorrowedLPBalance, uint256 lastBorrowedInvariant) {
        lastBorrowedInvariant = accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
        lastBorrowedLPBalance =  convertInvariantToLP(lastBorrowedInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
        lastLPBalance = lpBalance + lastBorrowedLPBalance;
    }

    /// @inheritdoc IShortStrategy
    function getLastFees(uint256 borrowRate, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply,
        uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum, uint256 lastCFMMFeeIndex,
        uint256 maxCFMMFeeLeverage, uint256 spread) public virtual override view returns(uint256 lastFeeIndex, uint256 updatedLastCFMMFeeIndex) {
        lastBlockNum = block.number - lastBlockNum;

        updatedLastCFMMFeeIndex = lastBlockNum > 0 ? calcCFMMFeeIndex(borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply, prevCFMMInvariant, prevCFMMTotalSupply, maxCFMMFeeLeverage) * lastCFMMFeeIndex / 1e18 : 1e18;

        // Calculate interest that would be charged to entire pool's liquidity debt if pool were updated in this transaction
        lastFeeIndex = calcFeeIndex(updatedLastCFMMFeeIndex, borrowRate, lastBlockNum, spread);
    }

    /// @inheritdoc IShortStrategy
    function totalAssetsAndSupply(VaultBalancesParams memory _params) public virtual override view returns(uint256 assets, uint256 supply) {
        // use lastFeeIndex and cfmmFeeIndex to hold maxCFMMFeeLeverage and spread respectively
        (uint256 borrowRate, uint256 utilizationRate, uint256 lastFeeIndex, uint256 cfmmFeeIndex) = calcBorrowRate(_params.LP_INVARIANT,
            _params.BORROWED_INVARIANT, _params.paramsStore, _params.pool);

        (lastFeeIndex, cfmmFeeIndex) = getLastFees(borrowRate, _params.BORROWED_INVARIANT, _params.latestCfmmInvariant,
            _params.latestCfmmTotalSupply, _params.lastCFMMInvariant, _params.lastCFMMTotalSupply, _params.LAST_BLOCK_NUMBER,
            _params.lastCFMMFeeIndex, lastFeeIndex, cfmmFeeIndex);

        // Total amount of GS LP tokens issued after protocol fees are paid
        assets = totalAssets(_params.BORROWED_INVARIANT, _params.LP_TOKEN_BALANCE, _params.latestCfmmInvariant, _params.latestCfmmTotalSupply, lastFeeIndex);

        // Calculates total CFMM LP tokens, including accrued interest, using state variables
        supply = totalSupply(_params.factory, _params.pool, cfmmFeeIndex, lastFeeIndex, utilizationRate, _params.totalSupply);
    }

    //********* Short Gamma Functions *********//

    /// @inheritdoc IShortStrategy
    function _depositNoPull(address to) external virtual override lock returns(uint256 shares) {
        shares = depositAssetsNoPull(to, false);
    }

    /// @notice Deposit CFMM LP tokens without calling transferFrom
    /// @dev There has to be unaccounted for CFMM LP tokens before calling this function
    /// @param to - address of receiver of GS LP tokens that will be minted
    /// @param isDepositReserves - true if depositing reserve tokens, false if depositing CFMM LP tokens
    /// @return shares - amount of GS LP tokens minted
    function depositAssetsNoPull(address to, bool isDepositReserves) internal virtual returns(uint256 shares) {
        // Unaccounted for CFMM LP tokens in GammaPool, presumably deposited by user requesting GS LP tokens
        uint256 assets = GammaSwapLibrary.balanceOf(s.cfmm, address(this)) - s.LP_TOKEN_BALANCE;

        // Update interest rate and state variables before conversion
        updateIndex();

        // Convert CFMM LP tokens (`assets`) to GS LP tokens (`shares`)
        shares = convertToShares(assets);
        // revert if request is for 0 GS LP tokens
        if(shares == 0) revert ZeroShares();

        // To prevent rounding errors, lock min shares in first deposit
        if(s.totalSupply == 0) {
            shares = shares - MIN_SHARES;
            assets = assets - MIN_SHARES;
            depositAssets(msg.sender, address(0), MIN_SHARES, MIN_SHARES, isDepositReserves);
        }
        // Track CFMM LP tokens (`assets`) in GammaPool and mint GS LP tokens (`shares`) to receiver (`to`)
        depositAssets(msg.sender, to, assets, shares, isDepositReserves);
    }

    /// @inheritdoc IShortStrategy
    function _withdrawNoPull(address to) external virtual override lock returns(uint256 assets) {
        (,assets) = withdrawAssetsNoPull(to, false); // withdraw CFMM LP tokens
    }

    /// @notice Transactions to perform before calling the deposit function in CFMM (e.g. transferring reserve tokens)
    /// @dev Tokens are usually sent to an address calculated by the `calcDepositAmounts` function before calling the deposit function in the CFMM
    /// @param amounts - amounts of reserve tokens to transfer
    /// @param to - destination address of reserve tokens
    /// @param data - information to verify transaction request in contract performing the transfer
    /// @return deposits - amounts deposited at `to`
    function preDepositToCFMM(uint256[] memory amounts, address to, bytes memory data) internal virtual returns (uint256[] memory deposits) {
        address[] storage tokens = s.tokens;
        deposits = new uint256[](tokens.length);
        for(uint256 i; i < tokens.length;) {
            // Get current reserve token balances in destination address
            deposits[i] = GammaSwapLibrary.balanceOf(tokens[i], to);
            unchecked {
                ++i;
            }
        }
        // Ask msg.sender to send reserve tokens to destination address
        ISendTokensCallback(msg.sender).sendTokensCallback(tokens, amounts, to, data);
        uint256 newBalance;
        for(uint256 i; i < tokens.length;) {
            if(amounts[i] > 0) {
                newBalance = GammaSwapLibrary.balanceOf(tokens[i], to);
                // Check destination address received reserve tokens by comparing with previous balances
                if(deposits[i] >= newBalance) revert WrongTokenBalance(tokens[i]);

                unchecked {
                    deposits[i] = newBalance - deposits[i];
                }
            } else {
                deposits[i] = 0;
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IShortStrategy
    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override lock returns(uint256[] memory reserves, uint256 shares) {
        {
            uint256 tokenLen = s.tokens.length;
            if(amountsDesired.length != tokenLen) revert InvalidAmountsDesiredLength();
            if(amountsMin.length != tokenLen) revert InvalidAmountsMinLength();
        }

        address payee; // address that will receive reserve tokens from depositor

        // Calculate amounts of reserve tokens to send and address to send them to
        (reserves, payee) = calcDepositAmounts(amountsDesired, amountsMin);

        // Transfer reserve tokens
        reserves = preDepositToCFMM(reserves, payee, data);

        // Call deposit function requesting CFMM LP tokens from CFMM and deposit them in GammaPool
        depositToCFMM(s.cfmm, address(this), reserves);

        // Mint GS LP Tokens to receiver (`to`) equivalent in value to CFMM LP tokens just deposited
        shares = depositAssetsNoPull(to, true);
    }

    /// @inheritdoc IShortStrategy
    function _withdrawReserves(address to) external virtual override lock returns(uint256[] memory reserves, uint256 assets) {
        (reserves, assets) = withdrawAssetsNoPull(to, true); // Withdraw reserve tokens
    }

    /// @dev Withdraw CFMM LP tokens from GammaPool or reserve tokens from CFMM and send them to receiver address (`to`)
    /// @param to - receiver address of CFMM LP tokens or reserve tokens
    /// @param askForReserves - send reserve tokens to receiver (`to`) if true, send CFMM LP tokens otherwise
    function withdrawAssetsNoPull(address to, bool askForReserves) internal virtual returns(uint256[] memory reserves, uint256 assets) {
        // Check is GammaPool has received GS LP tokens
        uint256 shares = s.balanceOf[address(this)];

        // Update interest rate and state variables before conversion
        updateIndex();

        // Convert GS LP tokens (`shares`) to CFMM LP tokens (`assets`)
        assets = convertToAssets(shares);
        // revert if request is for 0 CFMM LP tokens
        if(assets == 0) revert ZeroAssets();

        // Revert if not enough CFMM LP tokens in GammaPool
        if(assets > s.LP_TOKEN_BALANCE) revert ExcessiveWithdrawal();

        // Send CFMM LP tokens or reserve tokens to receiver (`to`) and burn corresponding GS LP tokens from GammaPool address
        reserves = withdrawAssets(address(this), to, address(this), assets, shares, askForReserves);
    }

    //************* ERC-4626 Functions ************//

    /// @dev Mint GS LP tokens (`shares`) to receiver (`to`) and track CFMM LP tokens (`assets`)
    /// @param caller - user address that requested to deposit CFMM LP tokens
    /// @param to - address receiving GS LP tokens (`shares`)
    /// @param assets - amount of CFMM LP tokens deposited
    /// @param shares - amount of GS LP tokens minted to receiver
    /// @param isDepositReserves - true if depositing reserve tokens, false if depositing CFMM LP tokens
    function depositAssets(address caller, address to, uint256 assets, uint256 shares, bool isDepositReserves) internal virtual {
        _mint(to, shares); // mint GS LP tokens to receiver (`to`)

        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        uint128 lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.LP_INVARIANT = lpInvariant;

        emit Deposit(caller, to, assets, shares);
        emit PoolUpdated(lpTokenBalance, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST,
            lpInvariant, s.BORROWED_INVARIANT, s.CFMM_RESERVES, isDepositReserves ? TX_TYPE.DEPOSIT_RESERVES : TX_TYPE.DEPOSIT_LIQUIDITY);

        afterDeposit(assets, shares);
    }

    /// @dev Withdraw CFMM LP tokens (`assets`) or their reserve token equivalent to receiver (`to`) by burning GS LP tokens (`shares`)
    /// @param caller - user address that requested to withdraw CFMM LP tokens
    /// @param to - address receiving CFMM LP tokens (`shares`) or their reserve token equivalent
    /// @param owner - address that owns GS LP tokens (`shares`) that will be burned
    /// @param assets - amount of CFMM LP tokens that will be sent to receiver (`to`)
    /// @param shares - amount of GS LP tokens that will be burned
    /// @param askForReserves - withdraw reserve tokens if true, CFMM LP tokens otherwise
    /// @return reserves - amount of reserve tokens withdrawn if `askForReserves` is true
    function withdrawAssets(address caller, address to, address owner, uint256 assets, uint256 shares, bool askForReserves) internal virtual returns(uint256[] memory reserves){
        if (caller != owner) { // If caller does not own GS LP tokens, check if allowed to burn them
            spendAllowance(owner, caller, shares);
        }

        checkExpectedUtilizationRate(assets, false);

        beforeWithdraw(assets, shares); // Before withdraw hook

        _burn(owner, shares); // Burn owner's GS LP tokens

        address cfmm = s.cfmm; // Save gas
        uint256 lpTokenBalance;
        uint128 lpInvariant;
        if(askForReserves) { // If withdrawing reserve tokens
            reserves = withdrawFromCFMM(cfmm, to, assets); // Changes lastCFMMTotalSupply and lastCFMMInvariant (less assets, less invariant)
            lpTokenBalance = GammaSwapLibrary.balanceOf(cfmm, address(this));
            uint256 lastCFMMInvariant = calcInvariant(cfmm, getLPReserves(cfmm, true));
            uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
            lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply));
            s.lastCFMMInvariant = uint128(lastCFMMInvariant); // Less invariant
            s.lastCFMMTotalSupply = lastCFMMTotalSupply; // Less CFMM LP tokens in existence
        } else { // If withdrawing CFMM LP tokens
            GammaSwapLibrary.safeTransfer(cfmm, to, assets); // doesn't change lastCFMMTotalSupply or lastCFMMInvariant
            lpTokenBalance = GammaSwapLibrary.balanceOf(cfmm, address(this));
            lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
        }
        s.LP_INVARIANT = lpInvariant;
        s.LP_TOKEN_BALANCE = lpTokenBalance;

        emit Withdraw(caller, to, owner, assets, shares);
        emit PoolUpdated(lpTokenBalance, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST,
            lpInvariant, s.BORROWED_INVARIANT, s.CFMM_RESERVES, askForReserves ? TX_TYPE.WITHDRAW_RESERVES : TX_TYPE.WITHDRAW_LIQUIDITY);
    }

    /// @dev Check if `spender` has permissions to spend `amount` of GS LP tokens belonging to `owner`
    /// @param owner - address that owns the GS LP tokens
    /// @param spender - address that will spend the GS LP tokens (`amount`) of the owner
    /// @param amount - amount of owner's GS LP tokens that will be spent
    function spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 allowed = s.allowance[owner][spender]; // Saves gas for limited approvals.
        if (allowed != type(uint256).max) { // If limited spending
            // Not allowed to spend that much
            if(allowed < amount) revert ExcessiveSpend();

            unchecked {
                s.allowance[owner][spender] = allowed - amount;
            }
        }
    }

    // ACCOUNTING LOGIC

    /// @dev Check if `spender` has permissions to spend `amount` of GS LP tokens belonging to `owner`
    /// @param assets - address that owns the GS LP tokens
    function convertToShares(uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = s.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        return supply == 0 || _totalAssets == 0 ? assets : (assets * supply / _totalAssets);
    }

    /// @dev Check if `spender` has permissions to spend `amount` of GS LP tokens belonging to `owner`
    /// @param shares - address that owns the GS LP tokens
    function convertToAssets(uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = s.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        return supply == 0 ? shares : (shares * (s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST) / supply);
    }

    // INTERNAL HOOKS LOGIC

    /// @dev Hook function that executes before withdrawal of CFMM LP tokens (`withdrawAssets`) but after token conversion
    /// @param assets - amount of CFMM LP tokens
    /// @param shares - amount GS LP tokens
    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    /// @dev Hook function that executes after deposit of CFMM LP tokens
    /// @param assets - amount of CFMM LP tokens
    /// @param shares - amount GS LP tokens
    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}
