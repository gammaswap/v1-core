// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for factory contract to create more GammaPool contracts.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev All instantiated GammaPoolFactory contracts must implement this interface
interface IGammaPoolFactory {
    /// @dev Event emitted when a new GammaPool is instantiated
    /// @param pool - address of new pool that is created
    /// @param cfmm - address of CFMM the GammaPool is created for
    /// @param protocolId - id identifier of GammaPool protocol (can be thought of as version)
    /// @param implementation - implementation address of GammaPool proxy contract. Because all GammaPools are created as proxy contracts
    /// @param tokens - ERC20 tokens of CFMM
    /// @param count - number of GammaPools instantiated including this contract
    event PoolCreated(address indexed pool, address indexed cfmm, uint16 indexed protocolId, address implementation, address[] tokens, uint256 count);

    /// @dev Event emitted when a GammaPool fee is updated
    /// @param pool - address of new pool whose fee is updated (zero address is default params)
    /// @param to - receiving address of protocol fees
    /// @param protocolFee - protocol fee share charged from interest rate accruals
    /// @param origFeeShare - protocol fee share charged on origination fees
    /// @param isSet - bool flag, true use fee information, false use GammaSwap default fees
    event FeeUpdate(address indexed pool, address indexed to, uint16 protocolFee, uint16 origFeeShare, bool isSet);

    /// @dev Event emitted when a GammaPool parameters are updated
    /// @param pool - address of GammaPool whose origination fee parameters will be updated
    /// @param origFee - loan opening origination fee in basis points
    /// @param extSwapFee - external swap fee in basis points, max 255 basis points = 2.55%
    /// @param emaMultiplier - multiplier used in EMA calculation of utilization rate
    /// @param minUtilRate1 - minimum utilization rate to calculate dynamic origination fee using exponential model
    /// @param minUtilRate2 - minimum utilization rate to calculate dynamic origination fee using linear model
    /// @param feeDivisor - fee divisor for calculating origination fee, based on 2^(maxUtilRate - minUtilRate1)
    /// @param liquidationFee - liquidation fee to charge during liquidations in basis points (1 - 255 => 0.01% to 2.55%)
    /// @param ltvThreshold - ltv threshold (1 - 255 => 0.1% to 25.5%)
    /// @param minBorrow - minimum liquidity amount that can be borrowed or left unpaid in a loan
    event PoolParamsUpdate(address indexed pool, uint16 origFee, uint8 extSwapFee, uint8 emaMultiplier, uint8 minUtilRate1, uint8 minUtilRate2, uint16 feeDivisor, uint8 liquidationFee, uint8 ltvThreshold, uint72 minBorrow);

    /// @dev Check if protocol is restricted. Which means only owner of GammaPoolFactory is allowed to instantiate GammaPools using this protocol
    /// @param _protocolId - id identifier of GammaPool protocol (can be thought of as version) that is being checked
    /// @return _isRestricted - true if protocol is restricted, false otherwise
    function isProtocolRestricted(uint16 _protocolId) external view returns(bool);

    /// @dev Set a protocol to be restricted or unrestricted. That means only owner of GammaPoolFactory is allowed to instantiate GammaPools using this protocol
    /// @param _protocolId - id identifier of GammaPool protocol (can be thought of as version) that is being restricted
    /// @param _isRestricted - set to true for restricted, set to false for unrestricted
    function setIsProtocolRestricted(uint16 _protocolId, bool _isRestricted) external;

    /// @notice Only owner of GammaPoolFactory can call this function
    /// @dev Add a protocol implementation to GammaPoolFactory contract. Which means GammaPoolFactory can create GammaPools with this implementation (protocol)
    /// @param _implementation - implementation address of GammaPool proxy contract. Because all GammaPools are created as proxy contracts
    function addProtocol(address _implementation) external;

    /// @notice Only owner of GammaPoolFactory can call this function
    /// @dev Update protocol implementation for a protocol.
    /// @param _protocolId - id identifier of GammaPool implementation
    /// @param _newImplementation - implementation address of GammaPool proxy contract. Because all GammaPools are created as proxy contracts
    function updateProtocol(uint16 _protocolId, address _newImplementation) external;

    /// @notice Only owner of GammaPoolFactory can call this function
    /// @dev Locks protocol implementation for upgradable protocols (<10000) so GammaPoolFactory can no longer update the implementation contract for this upgradable protocol
    /// @param _protocolId - id identifier of GammaPool implementation
    function lockProtocol(uint16 _protocolId) external;

    /// @dev Get implementation address that maps to protocolId. This is the actual implementation code that a GammaPool implements for a protocolId
    /// @param _protocolId - id identifier of GammaPool implementation (can be thought of as version)
    /// @return _address - implementation address of GammaPool proxy contract. Because all GammaPools are created as proxy contracts
    function getProtocol(uint16 _protocolId) external view returns (address);

    /// @dev Get beacon address that maps to protocolId. This beacon contract contains the implementation address of the GammaPool proxy
    /// @param _protocolId - id identifier of GammaPool implementation (can be thought of as version)
    /// @return _address - address of beacon of GammaPool proxy contract. Because all GammaPools are created as proxy contracts if there is one
    function getProtocolBeacon(uint16 _protocolId) external view returns (address);

    /// @dev Instantiate a new GammaPool for a CFMM based on an existing implementation (protocolId)
    /// @param _protocolId - id identifier of GammaPool protocol (can be thought of as version)
    /// @param _cfmm - address of CFMM the GammaPool is created for
    /// @param _tokens - addresses of ERC20 tokens in CFMM, used for validation during runtime of function
    /// @param _data - custom struct containing additional information used to verify the `_cfmm`
    /// @return _address - address of new GammaPool proxy contract that was instantiated
    function createPool(uint16 _protocolId, address _cfmm, address[] calldata _tokens, bytes calldata _data) external returns(address);

    /// @dev Mapping of bytes32 salts (key) to GammaPool addresses. The salt is predetermined and used to instantiate a GammaPool with a unique address
    /// @param _salt - the bytes32 key that is unique to the GammaPool and therefore also used as a unique identifier of the GammaPool
    /// @return _address - address of GammaPool that maps to bytes32 salt (key)
    function getPool(bytes32 _salt) external view returns(address);

    /// @dev Mapping of bytes32 salts (key) to GammaPool addresses. The salt is predetermined and used to instantiate a GammaPool with a unique address
    /// @param _pool - address of GammaPool that maps to bytes32 salt (key)
    /// @return _salt - the bytes32 key that is unique to the GammaPool and therefore also used as a unique identifier of the GammaPool
    function getKey(address _pool) external view returns(bytes32);

    /// @return count - number of GammaPools that have been instantiated through this GammaPoolFactory contract
    function allPoolsLength() external view returns (uint256);

    /// @dev Get pool fee parameters used to calculate protocol fees
    /// @param _pool - pool address identifier
    /// @return _to - address receiving fee
    /// @return _protocolFee - protocol fee share charged from interest rate accruals
    /// @return _origFeeShare - protocol fee share charged on origination fees
    /// @return _isSet - bool flag, true use fee information, false use GammaSwap default fees
    function getPoolFee(address _pool) external view returns (address _to, uint256 _protocolFee, uint256 _origFeeShare, bool _isSet);

    /// @dev Set pool fee parameters used to calculate protocol fees
    /// @param _pool - id identifier of GammaPool protocol (can be thought of as version)
    /// @param _to - address receiving fee
    /// @param _protocolFee - protocol fee share charged from interest rate accruals
    /// @param _origFeeShare - protocol fee share charged on origination fees
    /// @param _isSet - bool flag, true use fee information, false use GammaSwap default fees
    function setPoolFee(address _pool, address _to, uint16 _protocolFee, uint16 _origFeeShare, bool _isSet) external;

    /// @dev Call admin function in GammaPool contract
    /// @param _pool - address of GammaPool whose admin function will be called
    /// @param _data - custom struct containing information to execute in pool contract
    function execute(address _pool, bytes calldata _data) external;

    /// @dev Pause a GammaPool's function identified by a `_functionId`
    /// @param _pool - address of GammaPool whose functions we will pause
    /// @param _functionId - id of function in GammaPool we want to pause
    /// @return _functionIds - uint256 number containing all turned on (paused) function ids
    function pausePoolFunction(address _pool, uint8 _functionId) external returns(uint256 _functionIds) ;

    /// @dev Unpause a GammaPool's function identified by a `_functionId`
    /// @param _pool - address of GammaPool whose functions we will unpause
    /// @param _functionId - id of function in GammaPool we want to unpause
    /// @return _functionIds - uint256 number containing all turned on (paused) function ids
    function unpausePoolFunction(address _pool, uint8 _functionId) external returns(uint256 _functionIds) ;

    /// @return fee - protocol fee charged by GammaPool to liquidity borrowers in terms of basis points
    function fee() external view returns(uint16);

    /// @return origFeeShare - protocol fee share charged on origination fees
    function origFeeShare() external view returns(uint16);

    /// @return feeTo - address that receives protocol fees
    function feeTo() external view returns(address);

    /// @return feeToSetter - address that has the power to set protocol fees
    function feeToSetter() external view returns(address);

    /// @return feeTo - address that receives protocol fees
    /// @return fee - protocol fee charged by GammaPool to liquidity borrowers in terms of basis points
    /// @return origFeeShare - protocol fee share charged on origination fees
    function feeInfo() external view returns(address,uint256,uint256);

    /// @dev Get list of pools from start index to end index. If it goes over index it returns up to the max size of allPools array
    /// @param start - start index of pools to search
    /// @param end - end index of pools to search
    /// @return _pools - all pools requested
    function getPools(uint256 start, uint256 end) external view returns(address[] memory _pools);

    /// @dev See {IGammaPoolFactory-setFee}
    function setFee(uint16 _fee) external;

    /// @dev See {IGammaPoolFactory-setFeeTo}
    function setFeeTo(address _feeTo) external;

    /// @dev See {IGammaPoolFactory-setOrigFeeShare}
    function setOrigFeeShare(uint16 _origFeeShare) external;

    /// @dev See {IGammaPoolFactory-setFeeToSetter}
    function setFeeToSetter(address _feeToSetter) external;

}