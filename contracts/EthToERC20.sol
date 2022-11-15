// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceFeed.sol";
import "hardhat/console.sol";

contract EthToERC20 is ERC20 {
    PriceFeed priceFeed;
    mapping(string => pairPool) tokenPools;
    string[] contracts;

    struct pairPool {
        string token1;
        string token2;
        address token1Con;
        address token2Con;
        uint256 token1Amount;
        uint256 token2Amount;
        uint256 token1Seed;
        uint256 token2Seed;
        bool created;
    }

    modifier poolCreated(string memory _pair) {
        require(
            tokenPools[_pair].created,
            "There is no such token contract YET deployed in our system."
        );
        _;
    }

    modifier hasTokens(address _contract, uint256 _tokenAmount) {
        require(
            ERC20(_contract).balanceOf(msg.sender) >= _tokenAmount,
            "Insufficient ERC20 funds."
        );
        _;
    }

    constructor(
        address[] memory _tokenPools,
        string[] memory _tokenSymbols,
        address _priceFeed
    ) ERC20("EthToERC20", "EERC") {
        for (uint256 i = 0; i < _tokenPools.length; i += 2) {
            address token1Contract = _tokenPools[i];
            address token2Contract = _tokenPools[i + 1];
            string memory pair = string.concat(
                _tokenSymbols[i],
                "/",
                _tokenSymbols[i + 1]
            );

            contracts.push(pair);

            tokenPools[pair] = pairPool(
                _tokenSymbols[i],
                _tokenSymbols[i + 1],
                token1Contract,
                token2Contract,
                0,
                0,
                0,
                0,
                true
            );
        }
        priceFeed = PriceFeed(_priceFeed);
    }

    function deposit(string memory _pair, uint256 _tokenAmount)
        external
        payable
        poolCreated(_pair)
        hasTokens(tokenPools[_pair].token2Con, _tokenAmount)
    {
        address tokenContract = tokenPools[_pair].token2Con;
        ERC20(tokenContract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        tokenPools[_pair].token1Amount += msg.value;
        tokenPools[_pair].token2Amount += _tokenAmount;
        if (tokenPools[_pair].token1Seed == 0) {
            tokenPools[_pair].token1Seed = msg.value;
            tokenPools[_pair].token2Seed = _tokenAmount;
        }
    }

    function ethToERC20Swap(string memory _pair)
        external
        payable
        poolCreated(_pair)
    {
        pairPool memory pool = tokenPools[_pair];
        uint256 fee = msg.value / 500; // 0.2% fee
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newEthAmount = pool.token1Amount + msg.value;
        uint256 newTokenAmount = invariant / (newEthAmount - fee);
        uint256 tokensOut = pool.token2Amount - newTokenAmount;

        pool.token1Amount = newEthAmount;
        pool.token2Amount = newTokenAmount;
        tokenPools[_pair] = pool;

        ERC20(pool.token2Con).transfer(msg.sender, tokensOut);
    }

    function ERC20ToEthSwap(
        string memory _pair,
        address _tokenContract,
        uint256 _token2Amount
    ) external poolCreated(_pair) {
        pairPool memory pool = tokenPools[_pair];
        uint256 fee = _token2Amount / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newTokenPool = pool.token2Amount + _token2Amount;
        uint256 newEthPool = invariant / (newTokenPool - fee);
        uint256 ethOut = pool.token1Amount - newEthPool;

        pool.token1Amount = newEthPool;
        pool.token2Amount = newTokenPool;
        tokenPools[_pair] = pool;

        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _token2Amount
        );

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "Could not send eth.");
    }

    function getRelativePrice(
        string memory _pair,
        uint256 _tokenAmount,
        bool ethToERC20
    ) external view returns (uint256) {
        pairPool memory pool = tokenPools[_pair];
        if (!poolIsSeeded(_pair))
            return
                ethToERC20
                    ? 10**22 * priceFeed.getPrice(pool.token1Con)
                    : 10**22 * priceFeed.getPrice(pool.token2Con);

        uint256 fee = _tokenAmount / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newToken1Pool = ethToERC20
            ? pool.token1Amount + _tokenAmount
            : invariant / (pool.token2Amount + _tokenAmount - fee);
        uint256 newToken2Pool = ethToERC20
            ? invariant / (pool.token1Amount + _tokenAmount - fee)
            : pool.token2Amount + _tokenAmount;

        return
            ethToERC20
                ? pool.token2Amount - newToken2Pool
                : pool.token1Amount - newToken1Pool;
    }

    function estimateEthToERC20Deposit(
        string memory _pair,
        uint256 _tokenAmount,
        bool ethToERC20
    ) external view returns (uint256) {
        pairPool memory pool = tokenPools[_pair];
        if (!poolIsSeeded(_pair))
            return
                ethToERC20
                    ? ((10**16 * priceFeed.getPrice(pool.token1Con)) /
                        priceFeed.getPrice(pool.token2Con)) * _tokenAmount
                    : ((10**16 * priceFeed.getPrice(pool.token2Con)) /
                        priceFeed.getPrice(pool.token1Con)) * _tokenAmount;

        if (ethToERC20) {
            uint256 initialEthPrice = (10**16 * pool.token2Seed) /
                pool.token1Seed;
            uint256 newEthPool = pool.token1Amount + _tokenAmount;
            return newEthPool * initialEthPrice - pool.token2Amount * 10**16;
        } else {
            uint256 initialTokenPrice = (10**16 * pool.token1Seed) /
                pool.token2Seed;
            uint256 newTokenPool = pool.token2Amount + _tokenAmount;
            return
                newTokenPool * initialTokenPrice - pool.token1Amount * 10**16;
        }
    }

    function getContracts() external view returns (string[] memory) {
        return contracts;
    }

    function getPool(string memory _pair)
        external
        view
        returns (pairPool memory)
    {
        return tokenPools[_pair];
    }

    function poolIsSeeded(string memory _pair) internal view returns (bool) {
        return tokenPools[_pair].token1Seed != 0;
    }

    receive() external payable {}
}
