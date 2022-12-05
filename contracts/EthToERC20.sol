// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./PriceFeed.sol";
import "hardhat/console.sol";

contract EthToERC20 is ERC20 {
    PriceFeed priceFeed;
    mapping(string => pairPool) tokenPools;
    mapping(string => mapping(address => liquidityShare)) liquidityShares;
    mapping(string => address[]) liquidityProviders;
    string[] pools;
    uint128 withdrawPrecision;

    struct liquidityShare {
        uint256 t1Amount;
        uint256 t2Amount;
    }

    struct pairPool {
        string token1;
        string token2;
        address token1Con;
        address token2Con;
        uint256 token1Amount;
        uint256 token2Amount;
        uint256 token1Seed;
        uint256 token2Seed;
        uint256 t1Fees;
        uint256 t2Fees;
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
        withdrawPrecision = 30;
        priceFeed = PriceFeed(_priceFeed);
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
                0,
                0,
                true
            );
        }
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
        if (
            liquidityShares[_pair][msg.sender].t1Amount == 0 &&
            liquidityShares[_pair][msg.sender].t2Amount == 0
        ) liquidityProviders[_pair].push(msg.sender);
        liquidityShares[_pair][msg.sender].t1Amount += msg.value;
        liquidityShares[_pair][msg.sender].t2Amount += _tokenAmount;
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
        uint256 fee = msg.value / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newEthAmount = pool.token1Amount + msg.value;
        uint256 newTokenAmount = invariant / (newEthAmount - fee);
        uint256 tokensOut = pool.token2Amount - newTokenAmount;

        tokenPools[_pair].t1Fees += fee;
        tokenPools[_pair].token1Amount = newEthAmount;
        tokenPools[_pair].token2Amount = newTokenAmount;

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

        tokenPools[_pair].t2Fees += fee;
        tokenPools[_pair].token1Amount = newEthPool;
        tokenPools[_pair].token2Amount = newTokenPool;

        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _token2Amount
        );

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "Could not send eth.");
    }

    function withdrawShare(
        string memory _pair,
        uint256 _amount,
        bool _t1ToT2
    ) external {
        uint256 initT1Amount;
        uint256 initT2Amount;
        (initT1Amount, initT2Amount) = _t1ToT2
            ? (
                _amount,
                (tokenPools[_pair].token2Seed / tokenPools[_pair].token1Seed) *
                    _amount
            )
            : (
                (((10**8 * tokenPools[_pair].token1Seed) /
                    tokenPools[_pair].token2Seed) * _amount) / 10**8,
                _amount
            );

        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = getNoFeeWithdrawAmounts(
            _pair,
            initT1Amount,
            true
        );

        uint256 t1Bonus;
        uint256 t2Bonus;
        (t1Bonus, t2Bonus) = getFeeBonus(_pair, msg.sender);
        tokenPools[_pair].t1Fees -= t1Bonus;
        tokenPools[_pair].t2Fees -= t2Bonus;

        liquidityShares[_pair][msg.sender].t1Amount -= initT1Amount;
        liquidityShares[_pair][msg.sender].t2Amount -= initT2Amount;
        tokenPools[_pair].token1Amount -= t1Amount;
        tokenPools[_pair].token2Amount -= t2Amount;

        ERC20(tokenPools[_pair].token2Con).transfer(
            msg.sender,
            t2Amount + t2Bonus
        );
        (bool success, ) = msg.sender.call{value: t1Amount + t1Bonus}("");
        require(success, "Error refunding ether.");
    }

    function getFeeBonus(string memory _pair, address _user)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 t1Stake;
        uint256 t2Stake;
        (t1Stake, t2Stake) = getLpShare(_pair, _user);

        return (
            (tokenPools[_pair].t1Fees * t1Stake) / 10**18,
            (tokenPools[_pair].t2Fees * t2Stake) / 10**18
        );
    }

    function getLpShare(string memory _pair, address _user)
        public
        view
        returns (uint256, uint256)
    {
        uint256 t1Total;
        uint256 t2Total;
        (t1Total, t2Total) = getPoolDeposits(_pair);
        uint256 t1Stake = (10**18 * liquidityShares[_pair][_user].t1Amount) /
            t1Total;
        uint256 t2Stake = (10**18 * liquidityShares[_pair][_user].t2Amount) /
            t2Total;

        return (t1Stake, t2Stake);
    }

    function getPoolDeposits(string memory _pair)
        public
        view
        returns (uint256, uint256)
    {
        uint256 t1Total = 0;
        uint256 t2Total = 0;
        for (uint128 i = 0; i < liquidityProviders[_pair].length; i++) {
            address lp = liquidityProviders[_pair][i];
            t1Total += liquidityShares[_pair][lp].t1Amount;
            t2Total += liquidityShares[_pair][lp].t2Amount;
        }

        return (t1Total, t2Total);
    }

    function getUserDeposits(string memory _pair)
        external
        view
        returns (uint256, uint256)
    {
        return (
            liquidityShares[_pair][msg.sender].t1Amount,
            liquidityShares[_pair][msg.sender].t2Amount
        );
    }

    function abs(int256 _x) internal pure returns (uint256) {
        return _x >= 0 ? uint256(_x) : uint256(-_x);
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
                    ? 10**18 * priceFeed.getPrice(pool.token1Con)
                    : 10**18 * priceFeed.getPrice(pool.token2Con);

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

    function getNoFeeWithdrawAmounts(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) internal view returns (uint256, uint256) {
        uint256 t2Price = tokenPools[_pair].token2Seed /
            tokenPools[_pair].token1Seed;
        uint256 t1Price = (10**18 * tokenPools[_pair].token1Seed) /
            tokenPools[_pair].token2Seed;

        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = _t1ToT2
            ? (_tokenAmount, _tokenAmount * t2Price)
            : ((_tokenAmount * t1Price) / 10**18, _tokenAmount);

        if (tokenPools[_pair].token1Amount < t1Amount) {
            uint256 tokenDiff = abs(
                int256(tokenPools[_pair].token1Amount) - int256(t1Amount)
            );
            t1Amount = tokenPools[_pair].token1Amount;
            t2Amount += tokenDiff * t2Price;
        }

        if (tokenPools[_pair].token2Amount < t2Amount) {
            uint256 tokenDiff = abs(
                int256(tokenPools[_pair].token2Amount) -
                    int256(_tokenAmount * t2Price)
            );
            t1Amount = ((tokenDiff + t2Amount) * t1Price) / 10**18;
            t2Amount = tokenPools[_pair].token2Amount;
        }

        return (t1Amount, t2Amount);
    }

    function estimateWithdrawAmounts(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external view returns (uint256, uint256) {
        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = getNoFeeWithdrawAmounts(
            _pair,
            _tokenAmount,
            _t1ToT2
        );
        uint256 t1Bonus;
        uint256 t2Bonus;
        (t1Bonus, t2Bonus) = getFeeBonus(_pair, msg.sender);

        return (t1Amount + t1Bonus, t2Amount + t2Bonus);
    }

    function estimateDeposit(
        string memory _pair,
        uint256 _tokenAmount,
        bool ethToERC20
    ) external view returns (uint256[2] memory) {
        pairPool memory pool = tokenPools[_pair];
        if (!poolIsSeeded(_pair))
            return
                ethToERC20
                    ? [
                        _tokenAmount,
                        (((10**8 * priceFeed.getPrice(pool.token1Con)) /
                            priceFeed.getPrice(pool.token2Con)) *
                            _tokenAmount) / 10**8
                    ]
                    : [
                        (((10**8 * priceFeed.getPrice(pool.token2Con)) /
                            priceFeed.getPrice(pool.token1Con)) *
                            _tokenAmount) / 10**8,
                        _tokenAmount
                    ];

        if (ethToERC20) {
            uint256 initPrice = (10**8 * pool.token2Seed) / pool.token1Seed;
            uint256 tokenIn = (((pool.token1Amount + _tokenAmount) *
                initPrice) - (pool.token2Amount * 10**8)) / 10**8;
            return [_tokenAmount, tokenIn];
        } else {
            uint256 initPrice = (10**8 * pool.token1Seed) / pool.token2Seed;
            uint256 tokenIn = (((pool.token2Amount + _tokenAmount) *
                initPrice) - (pool.token1Amount * 10**8)) / 10**8;
            return [tokenIn, _tokenAmount];
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

    function getLiquidityProviders(string memory _pair)
        internal
        view
        returns (address[] memory)
    {
        return liquidityProviders[_pair];
    }

    function poolIsSeeded(string memory _pair) internal view returns (bool) {
        return tokenPools[_pair].token1Seed != 0;
    }

    receive() external payable {}
}
