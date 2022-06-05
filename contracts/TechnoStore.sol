// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IStore.sol";

contract TechnoStore is Ownable, IStore {
    uint constant RETURN_TIME = 100; // Grace period in blocktime
    uint constant PAGE_SIZE = 10;

    struct Transaction {
        uint blockNumber; // The block number when the transaction has been executed
        uint listIndex;   // Saves the index in buyers list for faster deletion
        bool executed;    // Used for validity checking
    }

    // Main product storage
    mapping(bytes32 => StoreProduct) private products;

    // Used to quickly check if a product exists
    mapping(bytes32 => bool) private productAdded;

    // Used for listing all products
    bytes32[] private productIds;

    // Main transactions storage
    mapping(bytes32 => mapping(address => Transaction)) private transactions;

    // Used for listing product buyers.
    mapping(bytes32 => address[]) private productBuyers;

    modifier productExists(bytes32 id) {
        require(productAdded[id], "product doesn't exist");
        _;
    }

    function addProduct(StoreProduct calldata newProduct) external onlyOwner override {
        require(bytes(newProduct.name).length > 0, "product name can't be empty");

        bytes32 productId = keccak256(abi.encodePacked(newProduct.name));        
        require(!productAdded[productId], "product with that name exists");

        products[productId] = newProduct;
        productAdded[productId] = true;
        productIds.push(productId);
        
        emit ProductAdded(newProduct.name, productId, newProduct.price, newProduct.quantity);
    }

    function restock(bytes32 productId, uint32 quantity) external onlyOwner productExists(productId) override {
        products[productId].quantity += quantity;

        emit ProductRestocked(productId, products[productId].quantity);
    }

    function buyProduct(bytes32 productId) external payable productExists(productId) override {
        StoreProduct storage product = products[productId];
        Transaction storage transaction = transactions[productId][msg.sender];

        require(!transaction.executed, "already bought");
        require(product.quantity > 0, "insufficient quantity");
        require(msg.value >= product.price, "not enough ETH");

        transaction.blockNumber = block.number;
        transaction.executed = true;
        transaction.listIndex = productBuyers[productId].length;

        productBuyers[productId].push(msg.sender);

        products[productId].quantity--;

        if (msg.value > product.price) {
            (bool sent, ) = msg.sender.call{value: msg.value - product.price}("");
            require(sent, "Failed to revert ETH");
        }

        emit ProductBought(productId, msg.sender);
    }

    function returnProduct(bytes32 productId) external productExists(productId) override {
        Transaction storage transaction = transactions[productId][msg.sender];
        require(transaction.executed, "product hasn't been bought");
        require(transaction.blockNumber + RETURN_TIME > block.number, "grace period ended");

        _removeBuyer(productId, transaction.listIndex);
        delete transactions[productId][msg.sender];

        products[productId].quantity++;

        (bool sent, ) = msg.sender.call{value: products[productId].price}("");
        require(sent, "Failed to refund ETH");

        emit ProductReturned(productId, msg.sender);
    }

    function getProduct(bytes32 productId) external view override returns(StoreProduct memory) {
        return products[productId];
    }

    function listBuyers(bytes32 productId, uint offset) external view productExists(productId) override returns(address[] memory, uint) {
        address[] storage buyers = productBuyers[productId];
        uint itemCount = _getItemCountForPage(offset, buyers.length);

        address[] memory result = new address[](itemCount);
        for(uint i=0; i < itemCount; ++i) {
            result[i] = buyers[i+offset];
        }

        return (result, buyers.length);
    }


    function listProducts(uint offset) external view override returns(StoreProductView[] memory, uint) {
        uint itemCount = _getItemCountForPage(offset, productIds.length);

        StoreProductView[] memory result = new StoreProductView[](itemCount);
        for(uint i=0; i < itemCount; ++i) {
            bytes32 id = productIds[offset + i];
            result[i] = StoreProductView(id, products[id]);
        }

        return (result, productIds.length);
    }

    function _getItemCountForPage(uint offset, uint listLength) internal pure returns(uint) {
        bool canFitPage = offset + PAGE_SIZE <= listLength;
        return canFitPage ? PAGE_SIZE : listLength - offset;
    }

    function _removeBuyer(bytes32 productId, uint buyerIndex) internal {
        // We'll assume the checks have been made, if the product was bought, to save gas
        address[] storage buyers = productBuyers[productId];
        address lastBuyer = buyers[buyers.length-1];
        buyers[buyerIndex] = lastBuyer;
        transactions[productId][lastBuyer].listIndex = buyerIndex;
        buyers.pop();
    }
}