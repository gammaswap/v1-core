<p align="center"><a href="https://gammaswap.com" target="_blank" rel="noopener noreferrer"><img width="100" src="https://gammaswap.com/assets/images/image02.png" alt="Gammaswap logo"></a></p>
  
<p align="center">
  <a href="https://github.com/gammaswap/v1-core/actions/workflows/main.yml"><img src="https://github.com/gammaswap/v1-core/actions/workflows/main.yml/badge.svg?branch=main" alt="Compile/Test/Publish">
</p>

# Steps to Run GammaSwap Tests Locally

1. Run ```npm install``` to install dependencies including hardhat.
2. Optional: copy [.env.example](.env.example) to .env. Fill details as needed.
3. Run ```npx hardhat test```

# Steps to Deploy To Contracts To Local Live Network

1. Fill in the details in [scripts/deploy.ts](scripts/deploy.ts) 
from deploying v1-periphery deployPreCore logs.
2. Run ```npx hardhat --network localhost run scripts/deployPreStrat.ts``` to deploy.
3. Follow instructions in v1-strategies readme to deploy locally. You must copy an
address from the deployPreCore script to v1-core's deploy script.
4. Fill in the details in [scripts/deployPostStrat.ts](scripts/deployPostStrat.ts) 
from deploying deployPreStrat and v1-strategies logs.
6. Run ```npx hardhat --network localhost run scripts/deployPostStrat.ts```.

Don't commit the secrets file.
