// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceFeed.sol";
import "hardhat/console.sol";

contract ERC20ToERC20 is ERC20 {
    PriceFeed priceFeed;
    mapping(string => pairPool) tokenPools;
    string[] pools;
    uint256 constant precisionMult = 10**16;

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
    ) ERC20("ERC20ToERC20", "ETET") {
        for (uint256 i = 0; i < _tokenPools.length; i += 2) {
            address token1Contract = _tokenPools[i];
            address token2Contract = _tokenPools[i + 1];
            string memory pair = string.concat(
                _tokenSymbols[i],
                "/",
                _tokenSymbols[i + 1]
            );

            pools.push(pair);

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

    function deposit(
        string memory _pair,
        uint256 _token1Amount,
        uint256 _token2Amount
    )
        external
        poolCreated(_pair)
        hasTokens(tokenPools[_pair].token1Con, _token1Amount)
        hasTokens(tokenPools[_pair].token2Con, _token2Amount)
    {
        tokenPools[_pair].token1Amount += _token1Amount;
        tokenPools[_pair].token2Amount += _token2Amount;
        if (tokenPools[_pair].token1Seed == 0) {
            tokenPools[_pair].token1Seed = _token1Amount;
            tokenPools[_pair].token2Seed = _token2Amount;
        }

        ERC20(tokenPools[_pair].token1Con).transferFrom(
            msg.sender,
            address(this),
            _token1Amount
        );
        ERC20(tokenPools[_pair].token2Con).transferFrom(
            msg.sender,
            address(this),
            _token2Amount
        );
    }

    function swap(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external {
        require(
            _t1ToT2
                ? ERC20(tokenPools[_pair].token1Con).balanceOf(msg.sender) >=
                    _tokenAmount
                : ERC20(tokenPools[_pair].token2Con).balanceOf(msg.sender) >=
                    _tokenAmount,
            "Insufficient ERC20 balance."
        );

        pairPool memory pool = tokenPools[_pair];
        uint256 fee = _tokenAmount / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newToken1Pool;
        uint256 newToken2Pool;
        uint256 tokensOut;
        if (_t1ToT2) {
            newToken1Pool = pool.token1Amount + _tokenAmount;
            newToken2Pool = invariant / (newToken1Pool - fee);
            tokensOut = pool.token2Amount - newToken2Pool;
        } else {
            newToken2Pool = pool.token2Amount + _tokenAmount;
            newToken1Pool = invariant / (newToken2Pool - fee);
            tokensOut = pool.token1Amount - newToken1Pool;
        }
        pool.token1Amount = newToken1Pool;
        pool.token2Amount = newToken2Pool;
        tokenPools[_pair] = pool;

        ERC20 fromContract = _t1ToT2
            ? ERC20(pool.token1Con)
            : ERC20(pool.token2Con);
        ERC20 toContract = _t1ToT2
            ? ERC20(pool.token2Con)
            : ERC20(pool.token1Con);

        fromContract.transferFrom(msg.sender, address(this), _tokenAmount);
        toContract.transfer(msg.sender, tokensOut);
    }

    function getRelativePrice(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external view returns (uint256, uint256) {
        pairPool memory pool = tokenPools[_pair];
        if (!poolIsSeeded(_pair))
            return (
                10**22 * priceFeed.getPrice(pool.token1Con),
                10**22 * priceFeed.getPrice(pool.token2Con)
            );

        uint256 fee = _tokenAmount / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newToken1Pool = _t1ToT2
            ? pool.token1Amount + _tokenAmount
            : invariant / (pool.token2Amount + _tokenAmount - fee);
        uint256 newToken2Pool = _t1ToT2
            ? pool.token2Amount + _tokenAmount
            : invariant / (pool.token1Amount + _tokenAmount);

        console.log(pool.token1Amount);
        console.log(pool.token2Amount);
        console.log(newToken1Pool);
        console.log(newToken2Pool);

        uint256 deltaX = 10**4 * newToken1Pool - pool.token1Amount; // 10**4 is to prevent deltaX being 0
        uint256 deltaY = 10**4 * pool.token2Amount - newToken2Pool; // 10**4 is to prevent deltaY being 0

        return ((10**22 * deltaY) / deltaX, (10**22 * deltaX) / deltaY);
    }

    function estimateDeposit(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external view returns (uint256) {
        pairPool memory pool = tokenPools[_pair];
        if (!poolIsSeeded(_pair))
            return
                _t1ToT2
                    ? ((precisionMult * priceFeed.getPrice(pool.token1Con)) /
                        priceFeed.getPrice(pool.token2Con)) * _tokenAmount
                    : ((precisionMult * priceFeed.getPrice(pool.token2Con)) /
                        priceFeed.getPrice(pool.token1Con)) * _tokenAmount;

        if (_t1ToT2) {
            uint256 initT1Price = (precisionMult * pool.token2Seed) /
                pool.token1Seed;
            uint256 newT1Pool = pool.token1Amount + _tokenAmount;
            return newT1Pool * initT1Price - pool.token2Amount * precisionMult;
        } else {
            uint256 initT2Price = (precisionMult * pool.token1Seed) /
                pool.token2Seed;
            uint256 newT2Pool = pool.token2Amount + _tokenAmount;
            return newT2Pool * initT2Price - pool.token1Amount * precisionMult;
        }
    }

    function getPools() external view returns (string[] memory) {
        return pools;
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

    function poolExists(string memory _pair) external view returns (bool) {
        return tokenPools[_pair].created;
    }
}
