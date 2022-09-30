# Steps to Run GammaSwap Tests Locally

1. Run ```npm install``` to install dependencies including hardhat.
2. Run ```npx hardhat test```

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
