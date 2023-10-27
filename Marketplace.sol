// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PrivateDomain.sol";
import "./Ownable.sol";

contract MarketPlace is Ownable  {
    uint256 public tokenDecimals = 8;
    uint256 public listingFee = 3;
    address public privTokenAddress;
    address public privDomainAddress;
    address public platformAddress;

    struct Offer {
        string domainName;
        uint256 tokenId;
        address seller;
        uint256 price;
        uint256 offerTime;
    }

    mapping(uint256 => Offer) public offers;
    uint256[] saleNFTIds;

    event DomainSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event OfferCancelled(uint256 indexed tokenId, address indexed seller, uint256 price);
    event OfferCreated(uint256 indexed tokenId, address indexed seller, uint256 price);

    constructor(address _nftContractAddress, address _tokenContractAddress) Ownable(msg.sender){
        privDomainAddress = _nftContractAddress;
        privTokenAddress = _tokenContractAddress;
        platformAddress = msg.sender;
    }

    function createOffer(uint256 _tokenId, uint256 _price) public {
        require(offers[_tokenId].seller == address(0),"This domain is already on sale");
        PrivateDomain PrivDomainContract = PrivateDomain(privDomainAddress);
        require(
            PrivDomainContract.ownerOf(_tokenId) == msg.sender,
             "Unauthorized to perform this action on the contract."
            );
        require(
            PrivDomainContract.getApproved(_tokenId) == address(this) || PrivDomainContract.isApprovedForAll(msg.sender,address(this)), 
            "Approval for this action is missing or insufficient."
        );
        _price = _price * 10 **tokenDecimals;
        string memory _domainName = PrivDomainContract.getDomainName(_tokenId); 
        Offer memory newOffer = Offer({
            domainName: _domainName,
            tokenId: _tokenId,
            seller: msg.sender,
            price: _price,
            offerTime: block.timestamp
        });

        offers[_tokenId] = newOffer;
        saleNFTIds.push(_tokenId);
        emit OfferCreated(_tokenId,msg.sender,_price);
    }

    function cancelOffer(uint256 _tokenId) public {
        require(offers[_tokenId].seller == msg.sender, "You are not the seller of this offer");
        uint price = offers[_tokenId].price;
        delete offers[_tokenId];
        removeOfferByNFTId(_tokenId);

        emit OfferCancelled(_tokenId,msg.sender,price);
    }

    function removeOfferByNFTId(uint256 _tokenId) private {
        for (uint256 i = 0; i < saleNFTIds.length; i++) {
            if (saleNFTIds[i] == _tokenId) {
                saleNFTIds[i] = saleNFTIds[saleNFTIds.length - 1];
                saleNFTIds.pop();
                offers[_tokenId].seller = address(0);
                break;
            }
        }
    }

    function buyDomain(uint256 _tokenId) public{
        require(calculateAndTransferDomainNFTPrice(msg.sender,_tokenId),"Transfer cannot be completed due to insufficient permissions.");
        address seller = offers[_tokenId].seller;
        require(seller != msg.sender, "Err");
        PrivateDomain PrivDomainContract = PrivateDomain(privDomainAddress);
        PrivDomainContract.transferFrom(seller, msg.sender, _tokenId);
        removeOfferByNFTId(_tokenId);
        emit DomainSold(_tokenId,seller,msg.sender,offers[_tokenId].price);
    }

    function calculateAndTransferDomainNFTPrice(address buyer, uint256 _tokenId) private returns(bool) {
        BurgerERC20 privTokenContract = BurgerERC20(privTokenAddress);
        uint price = getDomainOfferPrice(_tokenId);
        require(price <= privTokenContract.allowance(buyer, address(this)),"Allowance not set");
      
        address seller = offers[_tokenId].seller;
        uint feeAmount = (price * listingFee) / 100;
        uint reamingAmount = price - feeAmount;
        
        bool sellerTransactionStatus = privTokenContract.transferFrom(buyer, seller, reamingAmount);
        bool platformFeeTransactionStatus = privTokenContract.transferFrom(buyer, address(this), feeAmount);
        bool status = sellerTransactionStatus && platformFeeTransactionStatus;
        return status;
    }

    function getDomainOfferPrice(uint256 _tokenId) public view returns(uint256){
        uint price = offers[_tokenId].price;
        return price;
    } 

    function getSaleNFTs() public view returns (uint256[] memory) {
        return saleNFTIds;
    }

    function setPlatformFeeAddress(address newAddress) public onlyOwner returns (bool){
        platformAddress = newAddress;
        return true;
    }

    function changeListingFee(uint256 newFee) public onlyOwner returns(bool){
        listingFee = newFee;
        return true;
    }

    function checkOfferStatus(uint tokenId) public view returns(bool){
        return offers[tokenId].seller != address(0);
    }

    function getAllSaleItem() public view returns (Offer[] memory) {
        Offer[] memory saleItems = new Offer[](saleNFTIds.length);
        for (uint256 i = 0; i < saleNFTIds.length; i++) {
            uint256 tokenId = saleNFTIds[i];
            saleItems[i] = offers[tokenId];
        }
        return saleItems;
    }

    function withdrawPriva() public payable onlyOwner{
        BurgerERC20 privTokenContract = BurgerERC20(privTokenAddress);
        uint withdrawAmount = privTokenContract.balanceOf(address(this));
        privTokenContract.transfer(msg.sender, withdrawAmount);
    }

    function changeDomainCA(address _newAddress) public onlyOwner returns(bool){
        privDomainAddress = _newAddress;
        return true;
    }

    function changeTokenCA(address _newAddress) public onlyOwner returns(bool){
        privTokenAddress = _newAddress;
        return true;
    }

    function changeDecimals(uint _newValue) public onlyOwner returns(bool){
        tokenDecimals = _newValue;
        return true;
    }
 
}