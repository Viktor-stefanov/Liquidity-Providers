// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "./PriceFeed.sol";

contract EthToERC20 is ERC20 {
    PriceFeed priceFeed;
    mapping(address => pairPool) erc20Contracts;
    address[] contractsArr;

    struct pairPool {
        string symbol;
        uint256 ethAmount;
        uint256 tokenAmount;
        uint256 ethSeed; // we need these 2 fields because they tell us what the price
        uint256 tokenSeed; // should be and help us rebalance the pools later
        bool created;
    }

    modifier contractAvailable(address _contract) {
        require(
            erc20Contracts[_contract].created,
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

    constructor(address[] memory _erc20Contracts, address _priceFeed)
        payable
        ERC20("EthToERC20", "EERC")
    {
        for (uint256 i = 0; i < _erc20Contracts.length; i++) {
            address tokenContract = _erc20Contracts[i];
            contractsArr.push(tokenContract);
            erc20Contracts[tokenContract] = pairPool(
                ERC20(tokenContract).symbol(),
                0,
                0,
                0,
                0,
                true
            );
        }
        priceFeed = PriceFeed(_priceFeed);
    }

    function addToken(address _erc20Contract) external {
        require(
            erc20Contracts[_erc20Contract].created == false,
            "This token contract is already in the system."
        );

        contractsArr.push(_erc20Contract);
        erc20Contracts[_erc20Contract] = pairPool(
            ERC20(_erc20Contract).symbol(),
            0,
            0,
            0,
            0,
            true
        );
    }

    function depositEthToERC20(address _tokenContract, uint256 _tokenAmount)
        external
        payable
        contractAvailable(_tokenContract)
        hasTokens(_tokenContract, _tokenAmount)
    {
        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        erc20Contracts[_tokenContract].ethAmount += msg.value;
        erc20Contracts[_tokenContract].tokenAmount += _tokenAmount;
        if (erc20Contracts[_tokenContract].ethSeed == 0) {
            erc20Contracts[_tokenContract].ethSeed = msg.value;
            erc20Contracts[_tokenContract].tokenSeed = _tokenAmount;
        }
    }

    function ethToERC20Swap(address _tokenContract)
        external
        payable
        contractAvailable(_tokenContract)
    {
        pairPool memory pool = erc20Contracts[_tokenContract];
        uint256 fee = msg.value / 500; // 0.2% fee
        uint256 invariant = pool.ethAmount * pool.tokenAmount;
        uint256 newEthAmount = pool.ethAmount + msg.value;
        uint256 newTokenAmount = invariant / (newEthAmount - fee);

        pool.ethAmount = newEthAmount;
        pool.tokenAmount = newTokenAmount;
        erc20Contracts[_tokenContract] = pool;

        ERC20(_tokenContract).transferFrom(
            address(this),
            msg.sender,
            pool.tokenAmount - newTokenAmount
        );
    }

    function ERC20ToEthSwap(address _tokenContract, uint256 _tokenAmount)
        external
        contractAvailable(_tokenContract)
    {
        require(
            ERC20(_tokenContract).balanceOf(msg.sender) >= _tokenAmount,
            "Insufficient ERC20 balance."
        );
        pairPool memory pool = erc20Contracts[_tokenContract];
        uint256 fee = _tokenAmount / 500;
        uint256 invariant = pool.ethAmount * pool.tokenAmount;
        uint256 newTokenPool = pool.tokenAmount + _tokenAmount;
        uint256 newEthPool = invariant / (newTokenPool - fee);
        uint256 ethOut = pool.ethAmount - newEthPool;

        pool.ethAmount = newEthPool;
        pool.tokenAmount = newTokenPool;
        erc20Contracts[_tokenContract] = pool;

        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "Could not send eth.");
    }

    function ERC20ToEth(address _tokenContract, uint256 _tokenAmount)
        external
    {}

    function getRelativePrice(address _tokenContract)
        public
        view
        returns (uint256, uint256)
    {
        pairPool memory pool = erc20Contracts[_tokenContract];
        if (pool.ethAmount != 0) {
            uint256 relEthPrice = (pool.tokenAmount * 10**18) / pool.ethAmount;
            uint256 relTokenPrice = (pool.ethAmount * 10**18) /
                (pool.tokenAmount * 10**18);

            return (relEthPrice, relTokenPrice);
        }
    }

    function getContracts() external view returns (address[] memory) {
        return contractsArr;
    }

    function getPool(address _tokenContract)
        external
        view
        returns (pairPool memory)
    {
        return erc20Contracts[_tokenContract];
    }

    function poolIsSeeded(address _tokenContract) external view returns (bool) {
        return
            erc20Contracts[_tokenContract].created &&
            erc20Contracts[_tokenContract].ethSeed != 0;
    }

    function estimateDepositValues(address _tokenContract)
        external
        view
        returns (uint256, uint256)
    {
        pairPool memory pool = erc20Contracts[_tokenContract];
        if (pool.ethAmount > pool.ethSeed) {
            uint256 growthFactor = (10**18 * pool.ethAmount) / pool.ethSeed;
            uint256 shrinkFactor = (10**18 * pool.tokenSeed) - pool.tokenAmount;
            return (growthFactor, shrinkFactor);
        } else {
            uint256 growthFactor = (10**18 * pool.ethSeed) / pool.ethAmount;
            uint256 shrinkFactor = (10**18 * pool.tokenAmount) - pool.tokenSeed;
            return (growthFactor, shrinkFactor);
        }
    }

    receive() external payable {}
}
