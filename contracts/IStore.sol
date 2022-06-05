// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


/**
 * @title An interface for store smart contracts
 */
interface IStore {
    /**
     * @dev Emitted when a product is added to the store by the owner
     * @param name the name of the product which is added
     * @param id the newly generated id of the product which is added
     * @param price the price of the product which is added
     * @param quantity the initial quantity of the product
     */
    event ProductAdded(string indexed name, bytes32 id, uint price, uint32 quantity);
    /**
     * @dev Emitted when a product is restocked by the owner
     * @param id the id of the product which is restocked
     * @param newQuantity the quantity after the product is restocked
     */
    event ProductRestocked(bytes32 indexed id, uint32 newQuantity);
    /**
     * @dev Emitted when a product is bought by a given user
     * @param id the id of the product which is bought
     * @param buyer the address of the buyer
     */
    event ProductBought(bytes32 indexed id, address buyer);
    /**
     * @dev Emitted when a product is returned by a user who already bought the product
     * @param id the id of the product which is returned
     * @param buyer the address of the buyer who is returning the product
     */
    event ProductReturned(bytes32 indexed id, address buyer);

    // Basic product info
    struct StoreProduct {
        string name;
        uint price;
        uint32 quantity;
    }

    // Used when returning a list of products
    struct StoreProductView {
        bytes32 id;
        StoreProduct details;
    }

    // OWNER FUNCTIONS - The following functions should only be executable by the owner of the store.

    /**
     * @dev Adds a new product to the store only if a product with this name doesn't already exist.
     *      It must generate a new product id which should be later used to identify the product.
     *      This should emit the `ProductAdded` event to indicate the new product id.
     * @param newProduct product details
     */
    function addProduct(StoreProduct calldata newProduct) external;

    /**
     * @dev Restocks a given product with an additonal `quantity` items.
     *      It should only succeed if the product exists.
     * @param productId id of the product to restock
     * @param quantity the quantity with which to restock the product.
     */
    function restock(bytes32 productId, uint32 quantity) external;


    // USER FUNCTIONS - The following functions can be executed by anyone interacting with the store.

    /**
     * @dev Buys the given product for the message sender only if there is sufficient stock
     *      and there is enough ETH send with the message. Additonal ETH should be returned.
     * @param productId id of the product to buy
     */
    function buyProduct(bytes32 productId) external payable;

    /**
     * @dev Returns a given product, refunding it's price. Should be executable only if 
     *      the user already bought the product. 
     * @param productId id of the product to return
     */
    function returnProduct(bytes32 productId) external;

    /**
     * @dev Gets details for a given product by it's id.
     * @param productId id of the product to get info for
     */
    function getProduct(bytes32 productId) external view returns(StoreProduct memory);

    /**
     * @dev Lists a subset of a given product's buyers. Use offset to determine which buyers to return
     *      The number of returned buyers is up to implementation.
     * @param productId id of the product for which to get buyers
     * @param offset a helper value to determine which subset of buyers to get
     * @return buyers subset of the buyers with a given offset
     * @return totalCount total count of the product's buyers
     */
    function listBuyers(bytes32 productId, uint offset) external view returns(address[] memory buyers, uint totalCount);
    
    /**
     * @dev Lists a subset of the store's products. Use offset to determine which products to return
     *      The number of returned products is up to implementation.
     * @param offset a helper value to determine which subset of buyers to get
     * @return products subset of the products with a given offset
     * @return totalCount total count of the products
     */
    function listProducts(uint offset) external view returns(StoreProductView[] memory products, uint totalCount);
}