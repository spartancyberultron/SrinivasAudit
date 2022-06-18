// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DvlpMarketplace  is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _listingId;

    mapping(address => mapping(uint256 => NFTListing)) public NFTlistings;
    mapping(address => uint256) public balanceSold;

    uint256 private timeLimit;
    uint256 private tokenLimit = 2;

    struct NFTListing {
        uint256 listingId;
        uint256 tokenId;
        uint256 tokenAmmount;
        uint256 price;
        address payable seller;
        bool soldFl;
        bool saleFl;
    }

    mapping(address => uint256) private buyerTokenAmmount;

    event NFTListingAdded (
        uint256 indexed listingId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 tokenAmmount,
        uint256 price,
        address payable seller,
        bool soldFl,
        bool saleFl
    );

    function setTimeLimit (uint256 _limitD) public onlyOwner {
        timeLimit = block.timestamp + (_limitD * 1 days);
    }

    function getTimeLimit() public view onlyOwner returns (uint256 currentTimeLimit){
        currentTimeLimit = timeLimit;
    }

    function setTokenLimit (uint256 _limitT) public onlyOwner {
        tokenLimit = _limitT;
    }

    function getTokenLimit() public view onlyOwner returns (uint256 currentTokenLimit){
        currentTokenLimit = tokenLimit;
    }

    function addNFTListing (uint256 priceNFT , address contractNFT, uint256 tokenId, uint256 tokenAmmount ) public nonReentrant{
        ERC1155 contractToken = ERC1155(contractNFT);
        //require(priceNFT>0, "price must be minimum 1 wei");
        require(contractToken.balanceOf(msg.sender, tokenId)>0, "For listing caller must own the token");
        require(contractToken.isApprovedForAll(msg.sender, address(this)), "Contract must be approved");

        _listingId.increment();
        uint256 _itemId = _listingId.current();

        NFTlistings[contractNFT][_itemId] = NFTListing(_itemId, tokenId, tokenAmmount, priceNFT, payable(msg.sender), false, true);

        emit NFTListingAdded(_itemId, contractNFT, tokenId, tokenAmmount, priceNFT, payable(msg.sender), false, true);
    }

    function addNFTListingBatch (uint256[] memory _priceNFTs , address contractNFT, uint256[] memory _tokenIds, uint256[] memory _tokenAmmounts ) public nonReentrant{
        ERC1155 contractToken = ERC1155(contractNFT);
        require(contractToken.isApprovedForAll(msg.sender, address(this)), "Contract must be approved");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(contractToken.balanceOf(msg.sender, _tokenIds[i])>0, "For listing caller must own the token");
            //require(_priceNFTs[i]>0, "price must be minimum 1 wei");
            _listingId.increment();
            uint256 _itemId = _listingId.current();
            NFTlistings[contractNFT][_itemId] = NFTListing(_itemId, _tokenIds[i], _tokenAmmounts[i], _priceNFTs[i], payable(msg.sender), false, true);    
            emit NFTListingAdded(_itemId, contractNFT, _tokenIds[i], _tokenAmmounts[i], _priceNFTs[i], payable(msg.sender), false, true);
        }
    }

    function cancelNFTListing (address contractNFT, uint256 itemId) public nonReentrant{
        ERC1155 contractToken = ERC1155(contractNFT);
        NFTListing storage itemNFT = NFTlistings[contractNFT][itemId];
        uint256 tokenId = itemNFT.tokenId;
        require(contractToken.balanceOf(msg.sender, tokenId)>0, "For listing caller must own the token");
        require(contractToken.isApprovedForAll(msg.sender, address(this)), "Contract must be approved");

        itemNFT.saleFl = false;
    }

    function changeNFTPrice (address contractNFT, uint256 itemId, uint256 priceNFT) public nonReentrant{
        ERC1155 contractToken = ERC1155(contractNFT);
        NFTListing storage itemNFT = NFTlistings[contractNFT][itemId];
        uint256 tokenId = itemNFT.tokenId;
        require(contractToken.balanceOf(msg.sender, tokenId)>0, "For listing caller must own the token");
        require(contractToken.isApprovedForAll(msg.sender, address(this)), "Contract must be approved");
        //require(_priceNFT>0, "price must be minimum 1 wei");
        itemNFT.price = priceNFT;
    }

    function buyNFT (address contractNFT, uint256 itemId, uint256 tokenAmmount) public payable nonReentrant{
        ERC1155 contractToken = ERC1155(contractNFT);

        NFTListing storage itemNFT = NFTlistings[contractNFT][itemId];
        uint256 tokenId = itemNFT.tokenId;

        require(block.timestamp <= timeLimit && buyerTokenAmmount[msg.sender] < tokenLimit, "You already buy limited tokens");

        require(contractToken.balanceOf(itemNFT.seller, tokenId)>0, "can not sell something that does not exists");
        require(msg.value == itemNFT.price * tokenAmmount, "please send required funds");

        //balanceSold[itemNFT.seller] += msg.value;

        itemNFT.seller.transfer(msg.value);
        contractToken.safeTransferFrom(itemNFT.seller, msg.sender, tokenId, tokenAmmount, "");

        itemNFT.soldFl = true;
        itemNFT.saleFl = false;

        buyerTokenAmmount[msg.sender] += tokenAmmount;
    }

    function withdrawToken (uint256 tokenAmmount, address payable receiverAddress) public {
        require(tokenAmmount <= balanceSold[msg.sender], "insufficient ammount to withdraw");

        balanceSold[msg.sender] -= tokenAmmount;
        receiverAddress.transfer(tokenAmmount);
    }

    function fetchNFTListings(address contractNFT) public view returns(NFTListing[] memory){
        uint256 nftCount = _listingId.current();
        uint256 currentIndex = 0;

        NFTListing[] memory nfts = new NFTListing[](nftCount);
        for (uint i = 0; i < nftCount+1; i++){
            if (NFTlistings[contractNFT][i].saleFl == true){
                //uint256 currentId = NFTlistings[contractNFT][i].listingId;
                NFTListing storage currentItem = NFTlistings[contractNFT][i];
                nfts[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return nfts;
    }
}