// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./BurgerERC20.sol";
import "./ERC721.sol";


contract PrivateDomain is ERC721 {
    uint tokenDecimals = 8;
    uint privPrice = 100;

    address privTokenAddress;
    uint _tokenIds;
    address _owner;

    bool public isActiveMint = false;

    struct domainInfo{
        uint tokenId;
        string domainName;
        address domainOwner;
        string ipfsHash;
        bool isBlackList;
    }

    mapping(uint => string) _getDomain;
    mapping(string => domainInfo) _domainExists;
    mapping(address => domainInfo[]) domainsOwner;

    uint _totalSupply;

    event DomainMinted(address indexed owner, uint256 indexed tokenId, string indexed domainName, string tokenURI);
    event AwardDomain(address indexed owner, uint256 indexed tokenId, string indexed domainName, string tokenURI);
    event TransferDomain(address indexed oldOwner, address indexed newOwner, string domainName);


    constructor(address privAddress) ERC721("PrivaDomain", "PRIVA") {
          privTokenAddress = privAddress;
          _owner = msg.sender;
    }

    modifier onlyOwner{
        require(_owner == msg.sender,"");
        _;
    }
    
    modifier isAvailable(string memory domainName){
        require(!_domainExists[domainName].isBlackList, "Domain is blacklisted, unavailable!");
        _;
    }

    modifier checkStatusMint(){
        if(_owner != msg.sender){
            require(isActiveMint,"Mint is not active");
        }
        _;
    }

    function mintDomain(string memory domainName, string memory ipfsHash) public checkStatusMint{
        require(transferPriv(),"Payment not received");
       _tokenIds++;
        _safeMint(msg.sender, _tokenIds);
        registerDomain(domainName, _tokenIds, msg.sender, ipfsHash);
        _getDomain[_tokenIds] = domainName;
        _totalSupply++;
        emit DomainMinted(msg.sender, _tokenIds, domainName, ipfsHash);
    }

    function batchMintAwardDomains(
        string[] memory domainNames,
        string[] memory ipfsHashes,
        address[] memory recipients
    ) public onlyOwner {
        require(
            domainNames.length == ipfsHashes.length &&
            domainNames.length == recipients.length,
            "Input arrays must have the same length"
        );

        for (uint256 i = 0; i < domainNames.length; i++) {
            _tokenIds++;
            _safeMint(recipients[i], _tokenIds);
            registerDomain(domainNames[i], _tokenIds, recipients[i], ipfsHashes[i]);
            _getDomain[_tokenIds] = domainNames[i];
            _totalSupply++;
            emit AwardDomain(recipients[i], _tokenIds, domainNames[i], ipfsHashes[i]);
        }
    }

    function transfer(address to, uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId),"You are not authorized to operate on the domain");
        string memory domainName = _getDomain[tokenId];
        transferDomain(domainName, to);
        _transfer(msg.sender, to, tokenId);
        updateDomainInfo(tokenId, to, msg.sender);
        emit TransferDomain(msg.sender,to,domainName);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        string memory domainName = _getDomain[tokenId];
        transferDomain(domainName, to);
        _transfer(from, to, tokenId);
        updateDomainInfo(tokenId, to,from);
        emit TransferDomain(from,to,domainName);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        string memory domainName = _getDomain[tokenId];
        transferDomain(domainName, to);
        _safeTransfer(from, to, tokenId, "");
        updateDomainInfo(tokenId, to,from);
        emit TransferDomain(from,to,domainName);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        string memory domainName = _getDomain[tokenId];
        transferDomain(domainName, to);
        _safeTransfer(from, to, tokenId, _data);
        updateDomainInfo(tokenId, to,from);
        emit TransferDomain(from,to,domainName);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function checkAllowanceStatus(address spender, uint256 tokenId) public view returns(bool){
        return _isApprovedOrOwner(spender,tokenId);
    }

    function getDomainUrl(uint tokenId) public view returns(string memory){
        string memory domainName = _getDomain[tokenId];
        return string.concat(domainName, ".privapp.network");   
    }

    function tokenURI(uint256 tokenId) public view override  returns (string memory) {   
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory realBaseURI = "ipfs://";
        string memory domainName = _getDomain[tokenId];
        string memory ipfsHash = _domainExists[domainName].ipfsHash;
        return string.concat(realBaseURI, ipfsHash);
    }

    function changeTokenAddress(address newTokenAddress) public onlyOwner{
        privTokenAddress = newTokenAddress;
    }

    function getDomainName(uint tokenId) public view returns(string memory){
        return _getDomain[tokenId];
    }

    function getDomainInformationById(uint tokenId) public view returns(domainInfo memory ){
        string memory domainName = _getDomain[tokenId];
        return domainExists(domainName);
    }

    function totalSupply() external view returns (uint256){
        return _totalSupply;
    }

    function transferPriv() internal returns(bool status){
        return status = BurgerERC20(privTokenAddress).transferFrom(msg.sender, address(this), privPrice*10**tokenDecimals);
    }

    function withdraw(address who) public onlyOwner returns(bool status){
        return status = BurgerERC20(privTokenAddress).transfer(who, BurgerERC20(privTokenAddress).balanceOf(address(this)));
    }

    function changePrivPrice(uint newPrice) public onlyOwner{
        privPrice = newPrice;
    }

    function showPrivPrice() public view returns(uint){
        return privPrice;
    }

    function registerDomain(string memory _name, uint _tokenId, address who, string memory _uri) internal returns(bool){
        require(_domainExists[_name].domainOwner == address(0), "Domain name already exists");
        _domainExists[_name] = domainInfo(_tokenId,_name, who, _uri, false);
        domainsOwner[who].push(_domainExists[_name]);
        return true;
    }

    function updateDomainInfo(uint tokenId, address newOwner, address previousOwner) internal {
        require(_exists(tokenId), "Domain with the given tokenId does not exist");

        string memory domainName = _getDomain[tokenId];

        for (uint i = 0; i < domainsOwner[previousOwner].length; i++) {
            if (keccak256(bytes(domainsOwner[previousOwner][i].domainName)) == keccak256(bytes(domainName))) {
                domainsOwner[previousOwner][i] = domainsOwner[previousOwner][domainsOwner[previousOwner].length - 1];
                domainsOwner[previousOwner].pop();
                break;
            }
        }
        domainInfo memory domain = _domainExists[domainName];
        domain.domainOwner = newOwner;
        domainsOwner[newOwner].push(domain);
    }

    function domainExists(string memory domainName) public view returns (domainInfo memory) {
        return _domainExists[domainName];
    }
    
     function getAllDomains(address owner) public view returns(domainInfo[] memory){
        return domainsOwner[owner];
    }

    function transferDomain(string memory domainName, address to) internal isAvailable(domainName) {
        _domainExists[domainName].domainOwner = to;
    }

    function blockDomain(string memory domainName) public onlyOwner{
        _domainExists[domainName].isBlackList = true;
    }
    
    function unlockDomain(string memory domainName) public onlyOwner{
         _domainExists[domainName].isBlackList = false;
    }

    function registerDomainFromPinata(string memory domainName, string memory _ipfsHash) public {
        require(msg.sender == _domainExists[domainName].domainOwner, "You do not have transaction authorization for this token.");
        _domainExists[domainName].ipfsHash = _ipfsHash;
    }

    function changeOwner(address newOwner) public onlyOwner{
        _owner = newOwner;
    }

    function changeMintStatus() public onlyOwner{
        isActiveMint = !isActiveMint;
    }

    function changeDecimals(uint _newValue) public onlyOwner returns(bool){
        tokenDecimals = _newValue;
        return true;
    }

}