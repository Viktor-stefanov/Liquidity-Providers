// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/LibFacet.sol";
import "hardhat/console.sol";

contract EthToERC20 is ERC20, Modifiers {
    constructor() ERC20("EthToErc", "E2E") {}

    function depositEthToErc(string memory _pair, uint256 _tokenAmount)
        external
        payable
        Modifiers.poolCreated(_pair)
        Modifiers.hasTokens(_pair, 2, _tokenAmount)
    {
        /// TODO: Does this work?
        uint256 tokenGoal = estimateEthToErcDeposit(_pair, msg.value, true)[1];
        require(
            abs(int256(tokenGoal) - int256(_tokenAmount)) < 10**10,
            "Amount inserted is not helping the pool get to equilibrium state."
        );

        ERC20(LibFacet.facetStorage().tokenPools[_pair].token2Con).transferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );

        LibFacet.facetStorage().tokenPools[_pair].token1Amount += msg.value;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount += _tokenAmount;

        if (
            LibFacet
            .facetStorage()
            .liquidityShares[_pair][msg.sender].t1Amount ==
            0 &&
            LibFacet
            .facetStorage()
            .liquidityShares[_pair][msg.sender].t2Amount ==
            0
        ) LibFacet.facetStorage().liquidityProviders[_pair].push(msg.sender);
        LibFacet
        .facetStorage()
        .liquidityShares[_pair][msg.sender].t1Amount += msg.value;
        LibFacet
        .facetStorage()
        .liquidityShares[_pair][msg.sender].t2Amount += _tokenAmount;

        if (LibFacet.facetStorage().tokenPools[_pair].token1Seed == 0) {
            LibFacet.facetStorage().tokenPools[_pair].token1Seed = msg.value;
            LibFacet.facetStorage().tokenPools[_pair].token2Seed = _tokenAmount;
        }
    }

    function ethToErc20Swap(string memory _pair)
        external
        payable
        Modifiers.poolCreated(_pair)
    {
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[
            _pair
        ];
        uint256 fee = msg.value / LibFacet.facetStorage().feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newEthAmount = pool.token1Amount + msg.value;
        uint256 newTokenAmount = invariant / (newEthAmount - fee);
        uint256 tokensOut = pool.token2Amount - newTokenAmount;

        LibFacet.facetStorage().tokenPools[_pair].t1Fees += fee;
        LibFacet.facetStorage().tokenPools[_pair].token1Amount = newEthAmount;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount = newTokenAmount;

        ERC20(pool.token2Con).transfer(msg.sender, tokensOut);
    }

    function erc20ToEthSwap(
        string memory _pair,
        address _tokenContract,
        uint256 _tokenAmount
    ) external Modifiers.poolCreated(_pair) Modifiers.hasTokens(_pair, 1, _tokenAmount) {
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[
            _pair
        ];
        uint256 fee = _tokenAmount / LibFacet.facetStorage().feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newTokenPool = pool.token2Amount + _tokenAmount;
        uint256 newEthPool = invariant / (newTokenPool - fee);
        uint256 ethOut = pool.token1Amount - newEthPool;

        LibFacet.facetStorage().tokenPools[_pair].t2Fees += fee;
        LibFacet.facetStorage().tokenPools[_pair].token1Amount = newEthPool;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount = newTokenPool;

        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "Could not send eth.");
    }

    function ethToErcWithdraw(string memory _pair, uint256 _amount, bool _t1ToT2) external Modifiers.isShareHolder(_pair) Modifiers.hasShares(_pair, _amount, _t1ToT2) {
        LibFacet.withdrawShare(_pair, msg.sender, _amount, _t1ToT2, true);
    }

    function estimateEthToErcDeposit(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) public view returns (uint256[2] memory) {
        return LibFacet.estimateDeposit(_pair, _tokenAmount, _t1ToT2);
    }

    function getRelativePrice(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external view Modifiers.poolCreated(_pair) returns (uint256) {
        return LibFacet.getRelativePrice(_pair, _tokenAmount, _t1ToT2);
    }

    function getLpShare(string memory _pair, address _user)
        public
        view
        returns (uint256, uint256)
    {
       return LibFacet.getLpShare(_pair, _user); 
    }

    function estimateWithdrawAmounts(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external view returns (uint256, uint256) {
        return LibFacet.estimateWithdrawAmounts(_pair, _tokenAmount, _t1ToT2);
    }

    function getPoolDeposits(string memory _pair) external view returns (uint256, uint256){
        return LibFacet.getPoolDeposits(_pair);
    }

    function getUserDeposits(string memory _pair)
        external
        view
        returns (uint256, uint256)
    {
        return (
            LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount,
            LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount
        );
    }

    function abs(int256 _x) internal pure returns (uint256) {
        return _x >= 0 ? uint256(_x) : uint256(-_x);
    }

    function getPools() external view returns (string[] memory) {
        return LibFacet.facetStorage().pools;
    }

    function getLiquidityProviders(string memory _pair)
        internal
        view
        returns (address[] memory)
    {
        return LibFacet.facetStorage().liquidityProviders[_pair];
    }

    receive() external payable {}
}
