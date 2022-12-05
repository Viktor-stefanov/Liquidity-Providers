// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./PriceFeed.sol";
import "hardhat/console.sol";

contract EthToERC20 is ERC20 {
    PriceFeed priceFeed;
    mapping(string => PairPool) tokenPools;
    mapping(string => mapping(address => LiquidityShare)) liquidityShares;
    mapping(string => address[]) liquidityProviders;
    string[] pools;
    uint256 feeDivisor;
    uint256 precisionMult;

    struct LiquidityShare {
        uint256 t1Amount;
        uint256 t2Amount;
    }

    struct PairPool {
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

    modifier isShareHolder(string memory _pair) {
        require(
            liquidityShares[_pair][msg.sender].t1Amount > 0 &&
                liquidityShares[_pair][msg.sender].t2Amount > 0,
            "Only shareholders of the liquidity pool can call this function."
        );
        _;
    }

    modifier hasShares(
        string memory _pair,
        uint256 _share,
        bool _t1ToT2
    ) {
        require(
            _t1ToT2
                ? liquidityShares[_pair][msg.sender].t1Amount >= _share
                : liquidityShares[_pair][msg.sender].t2Amount >= _share,
            "Unable to withdraw more than has been deposited."
        );
        _;
    }

    constructor(
        address[] memory _tokenPools,
        string[] memory _tokenSymbols,
        address _priceFeed,
        uint256 _feeDivisor,
        uint256 _precisionMult
    ) ERC20("EthToERC20", "EERC") {
        precisionMult = 10**_precisionMult;
        feeDivisor = (10**18 * 100) / _feeDivisor;
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

            tokenPools[pair] = PairPool(
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
        uint256 tokenGoal = estimateDeposit(_pair, msg.value, true)[1];
        require(
            abs(int256(tokenGoal) - int256(_tokenAmount)) < 10**10,
            "Amount inserted is not helping the pool get to equilibrium state."
        );

        ERC20(tokenPools[_pair].token2Con).transferFrom(
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
        PairPool memory pool = tokenPools[_pair];
        uint256 fee = msg.value / feeDivisor;
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
        uint256 _tokenAmount
    )
        external
        poolCreated(_pair)
        hasTokens(tokenPools[_pair].token2Con, _tokenAmount)
    {
        PairPool memory pool = tokenPools[_pair];
        uint256 fee = _tokenAmount / feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newTokenPool = pool.token2Amount + _tokenAmount;
        uint256 newEthPool = invariant / (newTokenPool - fee);
        uint256 ethOut = pool.token1Amount - newEthPool;

        tokenPools[_pair].t2Fees += fee;
        tokenPools[_pair].token1Amount = newEthPool;
        tokenPools[_pair].token2Amount = newTokenPool;

        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "Could not send eth.");
    }

    function withdrawShare(
        string memory _pair,
        uint256 _amount,
        bool _t1ToT2
    ) external isShareHolder(_pair) hasShares(_pair, _amount, _t1ToT2) {
        uint256 initT1Amount;
        uint256 initT2Amount;
        uint256 ratio = _t1ToT2
            ? (precisionMult * _amount) /
                liquidityShares[_pair][msg.sender].t1Amount
            : (precisionMult * _amount) /
                liquidityShares[_pair][msg.sender].t2Amount;
        (initT1Amount, initT2Amount) = _t1ToT2
            ? (
                _amount,
                (ratio * liquidityShares[_pair][msg.sender].t2Amount) /
                    precisionMult
            )
            : (
                (ratio * liquidityShares[_pair][msg.sender].t1Amount) /
                    precisionMult,
                _amount
            );

        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = getNoFeeWithdrawAmounts(
            _pair,
            msg.sender,
            _amount,
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

    function estimateDeposit(
        string memory _pair,
        uint256 _tokenAmount,
        bool ethToERC20
    ) public view returns (uint256[2] memory) {
        PairPool memory pool = tokenPools[_pair];
        if (!poolIsSeeded(_pair))
            return
                ethToERC20
                    ? [
                        _tokenAmount,
                        (((precisionMult * priceFeed.getPrice(pool.token1Con)) /
                            priceFeed.getPrice(pool.token2Con)) *
                            _tokenAmount) / precisionMult
                    ]
                    : [
                        (((precisionMult * priceFeed.getPrice(pool.token2Con)) /
                            priceFeed.getPrice(pool.token1Con)) *
                            _tokenAmount) / precisionMult,
                        _tokenAmount
                    ];

        if (ethToERC20) {
            uint256 initPrice = (precisionMult * pool.token2Seed) /
                pool.token1Seed;
            uint256 tokenIn = (((pool.token1Amount + _tokenAmount) *
                initPrice) - (pool.token2Amount * precisionMult)) /
                precisionMult;
            return [_tokenAmount, tokenIn];
        } else {
            uint256 initPrice = (precisionMult * pool.token1Seed) /
                pool.token2Seed;
            uint256 tokenIn = (((pool.token2Amount + _tokenAmount) *
                initPrice) - (pool.token1Amount * precisionMult)) /
                precisionMult;
            return [tokenIn, _tokenAmount];
        }
    }

    function getNoFeeWithdrawAmounts(
        string memory _pair,
        address _user,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) internal view returns (uint256, uint256) {
        uint256 t2Price = (precisionMult * tokenPools[_pair].token2Seed) /
            tokenPools[_pair].token1Seed;
        uint256 t1Price = (precisionMult * tokenPools[_pair].token1Seed) /
            tokenPools[_pair].token2Seed;

        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = _t1ToT2
            ? (_tokenAmount, (_tokenAmount * t2Price) / precisionMult)
            : ((_tokenAmount * t1Price) / precisionMult, _tokenAmount);

        if (tokenPools[_pair].token1Amount < t1Amount) {
            uint256 tokenDiff = abs(
                int256(tokenPools[_pair].token1Amount) - int256(t1Amount)
            );
            t1Amount = tokenPools[_pair].token1Amount;
            uint256 ratio = _t1ToT2
                ? (precisionMult * _tokenAmount) /
                    liquidityShares[_pair][_user].t1Amount
                : (precisionMult * _tokenAmount) /
                    liquidityShares[_pair][_user].t2Amount;

            uint256 share = (ratio * liquidityShares[_pair][_user].t2Amount) /
                precisionMult;
            t2Amount = share + ((tokenDiff * t2Price) / precisionMult);
        }

        if (tokenPools[_pair].token2Amount < t2Amount) {
            uint256 tokenDiff = abs(
                int256(tokenPools[_pair].token2Amount) - int256(t2Amount)
            );
            t2Amount = tokenPools[_pair].token2Amount;
            uint256 ratio = _t1ToT2
                ? (precisionMult * _tokenAmount) /
                    liquidityShares[_pair][_user].t1Amount
                : (precisionMult * _tokenAmount) /
                    liquidityShares[_pair][_user].t2Amount;

            uint256 share = (ratio * liquidityShares[_pair][_user].t1Amount) /
                precisionMult;
            t1Amount = share + ((tokenDiff * t1Price) / precisionMult);
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
            msg.sender,
            _tokenAmount,
            _t1ToT2
        );
        uint256 t1Bonus;
        uint256 t2Bonus;
        (t1Bonus, t2Bonus) = getFeeBonus(_pair, msg.sender);

        return (t1Amount + t1Bonus, t2Amount + t2Bonus);
    }

    function getRelativePrice(
        string memory _pair,
        uint256 _tokenAmount,
        bool ethToERC20
    ) external view poolCreated(_pair) returns (uint256) {
        PairPool memory pool = tokenPools[_pair];
        uint256 fee = _tokenAmount / feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;

        return
            ethToERC20
                ? pool.token2Amount -
                    (invariant / (pool.token1Amount + _tokenAmount - fee))
                : pool.token1Amount -
                    (invariant / (pool.token2Amount + _tokenAmount - fee));
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
            (tokenPools[_pair].t1Fees * t1Stake) / precisionMult,
            (tokenPools[_pair].t2Fees * t2Stake) / precisionMult
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
        uint256 t1Stake = (precisionMult *
            liquidityShares[_pair][_user].t1Amount) / t1Total;
        uint256 t2Stake = (precisionMult *
            liquidityShares[_pair][_user].t2Amount) / t2Total;

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

    function getPools() external view returns (string[] memory) {
        return pools;
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
