// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import { StringUtils } from "./libraries/StringUtils.sol";
import {Base64} from "./libraries/Base64.sol";
import "hardhat/console.sol";

contract Domains is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  string public tld;
  address payable public owner;
  
  mapping(string => address) public domains;
  mapping(string => string) public records;
  mapping (uint => string) public names;

  string svgPrefix = '<svg xmlns="http://www.w3.org/2000/svg" width="270" height="270" fill="none"><path fill="url(#a)" d="M0 0h270v270H0z"/><defs><filter id="b" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="270" width="270"><feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity=".225" width="200%" height="200%"/></filter></defs><path d="M11.639.893c-1.942-.085-3.46 1.222-3.46 1.222a.5.5 0 0 0 .442.87s1.722-.435 3.025.869c.074.073.229.48.229.896 0 .417-.155.823-.229.896L8.734 8.56h-.002a.5.5 0 0 0-.24-.059.5.5 0 0 0-.346.146l-8 8a.5.5 0 0 0 0 .708l2 2a.5.5 0 0 0 .708 0l8-8a.5.5 0 0 0 .087-.588l3.809-3.809.543.543-.147.146a.5.5 0 0 0 0 .708l1.5 1.5a.5.5 0 0 0 .708 0l2.5-2.5a.5.5 0 0 0 0-.708l-1.5-1.5a.5.5 0 0 0-.708 0l-.146.147-.559-.559v-.002a.5.5 0 0 0-.087-.586l-1.5-1.5a.5.5 0 0 0-.588-.087l-.412-.413C13.49 1.284 12.52.931 11.639.893zm-.043 1c.661.028 1.35.26 2.05.96l.75.75a.5.5 0 0 0 .588.088l.825.825a.5.5 0 0 0 0 .002.5.5 0 0 0 .087.586l1.25 1.25a.5.5 0 0 0 .708 0L18 6.207l.793.793L17 8.793 16.207 8l.147-.146a.5.5 0 0 0 0-.708l-1.25-1.25a.5.5 0 0 0-.708 0l-4.146 4.147-.793-.793 2.897-2.896c.426-.427.521-1.02.521-1.604 0-.583-.095-1.177-.521-1.604-.575-.574-1.195-.836-1.791-1.001.346-.102.644-.27 1.033-.252zM8.5 9.707 9.793 11 2.5 18.293 1.207 17 8.5 9.707z" style="stroke:none;stroke-width:0" transform="matrix(3 0 0 3 15 15)" fill="#fff"/><linearGradient id="a" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#020024"/><stop offset="1" stop-color="#a42e03" stop-opacity=".99"/></linearGradient><text x="32.5" y="231" font-size="27" fill="#fff" filter="url(#b)" font-family="Plus Jakarta Sans,DejaVu Sans,Noto Color Emoji,Apple Color Emoji,sans-serif" font-weight="bold">';
  string svgSuffix = '</text></svg>';

  // We make the contract "payable" by adding this to the constructor
  constructor(string memory _tld) payable ERC721("Builder name service", "BUILD") {
    owner = payable(msg.sender);
    tld = _tld;
    console.log("%s name service deployed", _tld);
  }

  // This function will give us the price of a domain based on length
  function price(string calldata name) public pure returns(uint) {
    uint len = StringUtils.strlen(name);
    require(len > 0);
    if (len == 3) {
      return 5 * 10**15; // 5 MATIC = 5 000 000 000 000 000 000 (18 decimals). We're going with 0.005 Matic cause the faucets don't give a lot
    } else if (len == 4) {
      return 3 * 10**15; // To charge smaller amounts, reduce the decimals. This is 0.003
    } else {
      return 1 * 10**15; // 0.001 Matic
    }
  }

  function withdraw() public onlyOwner {
    uint amount = address(this).balance;
    
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Failed to withdraw Matic");
  } 

  function register(string calldata name) public payable {
      // Check that the name is unregistered
      if (domains[name] != address(0)) revert AlreadyRegistered();
      if (!validDomain(name)) revert InvalidName(name);

      uint _price = price(name);

      require(msg.value >= _price, "Not enough Matic for domain registration");


      string memory _name = string(abi.encodePacked(name, ".", tld));
      string memory finalSvg = string(abi.encodePacked(svgPrefix, _name, svgSuffix));
      uint256 newRecordId = _tokenIds.current();
      uint256 length = StringUtils.strlen(finalSvg);
      string memory strLen = Strings.toString(length);

      console.log("Registering %s.%s on the contract with tokenID %d", name, tld, newRecordId);

      string memory json = Base64.encode(
        bytes(
          string(
            abi.encodePacked(
              '{"name": "',
              _name,
              '", "description": "A domain on the Builder name service", "image": "data:image/svg+xml;base64,',
              Base64.encode(bytes(finalSvg)),
              '","length":"',
              strLen,
              '"}'
            )
          )
        )
      );

    string memory finalTokenUri = string( abi.encodePacked("data:application/json;base64,", json));

    console.log("\n--------------------------------------------------------");
    console.log("Final tokenURI", finalTokenUri);
    console.log("--------------------------------------------------------\n");

    _safeMint(msg.sender, newRecordId);
    _setTokenURI(newRecordId, finalTokenUri);
    domains[name] = msg.sender;
    names[newRecordId] = name;
    _tokenIds.increment();
  }

  function getAllDomains() public view returns (string[] memory) {
    console.log("Getting all names from contract");
    string[] memory allNames = new string[](_tokenIds.current());
    for (uint i = 0; i < _tokenIds.current(); i++) {
      allNames[i] = names[i];
      console.log("Name for token %d is %s", i, allNames[i]);
    }

    return allNames;
  }

  function getAddress(string calldata name) public view returns (address) {
      return domains[name];
  }

  function setRecord(string calldata name, string calldata record) public {
      // Check that the owner is the transaction sender
      if (msg.sender != domains[name]) revert Unauthorized();
      records[name] = record;
  }

  function getRecord(string calldata name) public view returns(string memory) {
      return records[name];
  }

  modifier onlyOwner() {
    require(isOwner());
    _;
  }

  function isOwner() public view returns (bool) {
    return msg.sender == owner;
  }

  function validDomain(string calldata name) public pure returns(bool) {
    return StringUtils.strlen(name) >= 3 && StringUtils.strlen(name) <= 10;
  }

  error Unauthorized();
  error AlreadyRegistered();
  error InvalidName(string name);
}