// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "./PriceFeed.sol";

contract EthToERC20 is ERC20 {
    PriceFeed priceFeed;
    mapping(address => mapping(address => pairPool)) tokenPools;
    address[] contractsArr;

    struct pairPool {
        string token1;
        string token2;
        uint256 token1Amount;
        uint256 token2Amount;
        uint256 token1Seed;
        uint256 token2Seed;
        bool created;
    }

    modifier poolCreated(address _token1, address _token2) {
        require(
            tokenPools[_token1][_token2].created,
            "There is no such token contract YET deployed in our system."
        );
        _;
    }

    modifier hasTokens(address _contract, uint256 _token2Amount) {
        require(
            ERC20(_contract).balanceOf(msg.sender) >= _token2Amount,
            "Insufficient ERC20 funds."
        );
        _;
    }

    constructor(
        address[] memory _tokenPools,
        string[] memory _tokenSymbols,
        address _priceFeed
    ) payable ERC20("EthToERC20", "EERC") {
        for (uint256 i = 0; i < _tokenPools.length; i += 2) {
            address token1Contract = _tokenPools[i];
            address token2Contract = _tokenPools[i + 1];
            contractsArr.push(token1Contract);
            contractsArr.push(token2Contract);
            tokenPools[token1Contract][token2Contract] = pairPool(
                _tokenSymbols[i],
                _tokenSymbols[i + 1],
                0,
                0,
                0,
                0,
                true
            );
        }
        priceFeed = PriceFeed(_priceFeed);
    }

    function addToken(address token1Contract, address token2Contract) external {
        require(
            tokenPools[token1Contract][token2Contract].created == false,
            "This token contract is already in the system."
        );

        contractsArr.push(token1Contract);
        contractsArr.push(token2Contract);
        tokenPools[token1Contract][token2Contract] = pairPool(
            ERC20(token1Contract).symbol(),
            ERC20(token2Contract).symbol(),
            0,
            0,
            0,
            0,
            true
        );
    }

    function depositEthToERC20(
        address _ethContract,
        address _tokenContract,
        uint256 _tokenAmount
    )
        external
        payable
        poolCreated(_ethContract, _tokenContract)
        hasTokens(_tokenContract, _tokenAmount)
    {
        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        tokenPools[_ethContract][_tokenContract].token1Amount += msg.value;
        tokenPools[_ethContract][_tokenContract].token2Amount += _tokenAmount;
        if (tokenPools[_ethContract][_tokenContract].token1Seed == 0) {
            tokenPools[_ethContract][_tokenContract].token1Seed = msg.value;
            tokenPools[_ethContract][_tokenContract].token2Seed = _tokenAmount;
        }
    }

    function depositERC20ToERC20(
        address _token1Contract,
        address _token2Contract,
        uint256 _token1Amount,
        uint256 _token2Amount
    )
        external
        poolCreated(_token1Contract, _token2Contract)
        hasTokens(_token1Contract, _token1Amount)
        hasTokens(_token2Contract, _token2Amount)
    {
        tokenPools[_token1Contract][_token2Contract]
            .token1Amount += _token1Amount;
        tokenPools[_token1Contract][_token2Contract]
            .token2Amount += _token2Amount;
        if (tokenPools[_token1Contract][_token2Contract].token1Seed == 0) {
            tokenPools[_token1Contract][_token2Contract]
                .token1Seed = _token1Amount;
            tokenPools[_token1Contract][_token2Contract]
                .token2Seed = _token2Amount;
        }

        ERC20(_token1Contract).transferFrom(
            msg.sender,
            address(this),
            _token1Amount
        );
        ERC20(_token2Contract).transferFrom(
            msg.sender,
            address(this),
            _token2Amount
        );
    }

    function ethToERC20Swap(address _ethContract, address _tokenContract)
        external
        payable
        poolCreated(_ethContract, _tokenContract)
    {
        pairPool memory pool = tokenPools[_ethContract][_tokenContract];
        uint256 fee = msg.value / 500; // 0.2% fee
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newEthAmount = pool.token1Amount + msg.value;
        uint256 newTokenAmount = invariant / (newEthAmount - fee);
        uint256 tokensOut = pool.token2Amount - newTokenAmount;

        pool.token1Amount = newEthAmount;
        pool.token2Amount = newTokenAmount;
        tokenPools[_ethContract][_tokenContract] = pool;

        ERC20(_tokenContract).transfer(msg.sender, tokensOut);
    }

    function ERC20ToEthSwap(
        address _ethContract,
        address _tokenContract,
        uint256 _token2Amount
    ) external poolCreated(_ethContract, _tokenContract) {
        pairPool memory pool = tokenPools[_ethContract][_tokenContract];
        uint256 fee = _token2Amount / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newTokenPool = pool.token2Amount + _token2Amount;
        uint256 newEthPool = invariant / (newTokenPool - fee);
        uint256 ethOut = pool.token1Amount - newEthPool;

        pool.token1Amount = newEthPool;
        pool.token2Amount = newTokenPool;
        tokenPools[_ethContract][_tokenContract] = pool;

        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _token2Amount
        );

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "Could not send eth.");
    }

    function ERC20ToERC20Swap(
        address _token1Contract,
        address _token2Contract,
        uint256 _tokenAmount
    ) external hasTokens(_token1Contract, _tokenAmount) {
        pairPool memory pool = tokenPools[_token1Contract][_token2Contract];
        uint256 fee = _tokenAmount / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newToken1Pool = pool.token1Amount + _tokenAmount;
        uint256 newToken2Pool = invariant / (newToken1Pool - fee);
        uint256 token2Out = pool.token2Amount - newToken2Pool;

        pool.token1Amount = newToken1Pool;
        pool.token2Amount = newToken2Pool;
        tokenPools[_token1Contract][_token2Contract] = pool;

        ERC20(_token1Contract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        ERC20(_token2Contract).transfer(msg.sender, token2Out);
    }

    function getRelativePrice(address _token1Contract, address _token2Contract)
        public
        view
        returns (uint256)
    {
        require(
            poolIsSeeded(_token1Contract, _token2Contract),
            "Pool has not yet been seeded."
        );

        pairPool memory pool = tokenPools[_token1Contract][_token2Contract];
        uint256 t1ToT2 = (pool.token2Amount * 10**36) / pool.token1Amount;

        return t1ToT2;
    }

    function getContracts() external view returns (address[] memory) {
        return contractsArr;
    }

    function getPool(address _token1Contract, address _token2Contract)
        external
        view
        returns (pairPool memory)
    {
        return tokenPools[_token1Contract][_token2Contract];
    }

    function poolIsSeeded(address _token1Contract, address _token2Contract)
        public
        view
        returns (bool)
    {
        return tokenPools[_token1Contract][_token2Contract].token1Seed != 0;
    }

    function estimateFromToDeposit(
        address _token1Contract,
        address _token2Contract
    ) external view returns (uint256, uint256) {
        pairPool memory pool = tokenPools[_token1Contract][_token2Contract];
        uint256 t1ToT2Price = pool.token1Amount == pool.token1Seed
            ? pool.token1Seed
            : ((10**18 * pool.token1Seed) / pool.token1Amount) *
                pool.token1Seed;
        uint256 t2ToT1Price = pool.token2Amount == pool.token2Seed
            ? pool.token2Seed
            : ((10**18 * pool.token2Seed) / pool.token2Amount) *
                pool.token2Seed;

        return (t1ToT2Price, t2ToT1Price);
    }

    function getSymbol(address _tokenContract)
        external
        view
        returns (string memory)
    {
        return ERC20(_tokenContract).symbol();
    }

    receive() external payable {}
}
