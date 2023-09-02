import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import NFTActorClass "../NFT/nft";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Iter "mo:base/Iter";

actor OpenD {

    private type Listing = { // create a custom type to store info of listed NFT
        itemOwner: Principal;
        itemPrice: Nat;
    };

    var mapOfNFTs = HashMap.HashMap<Principal, NFTActorClass.NFT>(1, Principal.equal, Principal.hash); // to store <NFTPrincipalId: NFT>
    var mapOfOwners = HashMap.HashMap<Principal, List.List<Principal>>(1, Principal.equal, Principal.hash); // to store <OwnerPrincipalId: List of NFTPrincipalIds>
    var mapOfListings = HashMap.HashMap<Principal, Listing>(1, Principal.equal, Principal.hash); // to store data of <NFTId: {owner, price}>

    public shared(msg) func mint(imgData: [Nat8], name: Text) : async Principal { // mint nft from an ecommerce page
        let owner : Principal = msg.caller;

        Debug.print(debug_show((Cycles.balance()))); // check cycles balance
        Cycles.add(100_500_000_000); // add cycles
        let newNFT = await NFTActorClass.NFT(name, owner, imgData); // mint nft through the NFT actor class
        Debug.print(debug_show((Cycles.balance())));

        let newNFTPrincipal = await newNFT.getCanisterId(); // get the principal id of new NFT
        
        mapOfNFTs.put(newNFTPrincipal, newNFT); // store new NFT into NFTMap
        addToOwnerMap(owner, newNFTPrincipal); // store new NFT into ownerMap

        return newNFTPrincipal;
    };      

    private func addToOwnerMap(owner: Principal, nftId: Principal) { // to store new NFT into ownerMap
        var ownedNFTs : List.List<Principal> = switch (mapOfOwners.get(owner)) { // get the list of NFTs the owner owned
            case null List.nil<Principal>(); // in case the owener ID doesn't exist in the map
            case (?result) result;
        };

        ownedNFTs := List.push(nftId, ownedNFTs); // save new NFT to the list
        mapOfOwners.put(owner, ownedNFTs); // save into the ownerMap
    };

    public query func getOwnedNFTs(user: Principal) : async [Principal] { // query for NFTs owned by a user
        var userNFTs : List.List<Principal> = switch (mapOfOwners.get(user)) { 
            case null List.nil<Principal>(); // in case the user ID doesn't exist in the map
            case (?result) result;
        };

        return List.toArray(userNFTs);
    };

    public query func getListedNFTs() : async [Principal] { // query for listed NFTs
        let ids = Iter.toArray(mapOfListings.keys());
        return ids;
    };

    public shared(msg) func listItem(id: Principal, price: Nat) : async Text{
        var item : NFTActorClass.NFT = switch (mapOfNFTs.get(id)) { // get the required NFT id
            case null return "NFT does not exist."; // in case the owener ID doesn't exist in the map
            case (?result) result;
        };

        let owner = await item.getOwner(); // get the owner of the NFT
        if (Principal.equal(owner, msg.caller)) { // check the caller is the owner of the NFT
            let newListing : Listing = { // create a new Listing instance
                itemOwner = owner;
                itemPrice = price;
            };
            mapOfListings.put(id, newListing); // store into the Listing Map
            return "Success";
        } else {
            return "You don't own the NFT.";
        }
    };

    public query func getOpenDCanisterID() : async Principal {
        return Principal.fromActor(OpenD);
    };

    public query func isListed(id: Principal) : async Bool {
        if (mapOfListings.get(id) == null) {
            return false;
        } else {
            return true;
        }
    };

    public query func getOriginalOwner(id: Principal) : async Principal { // query for a NFT's original owner
        var listing : Listing = switch (mapOfListings.get(id)) {
            case null return Principal.fromText("");
            case (?result) result;
        };

        return listing.itemOwner;
    };

    public query func getListedNFTPrice(id: Principal) : async Nat { // query for price of listed NFT
        var listing : Listing = switch (mapOfListings.get(id)) {
            case null return 0;
            case (?result) result;
        };

        return listing.itemPrice;
    };

    public shared(msg) func completePurchase(id: Principal, ownerId: Principal, newOwnerId: Principal) : async Text {
        // transfer the ownership of sold NFT and update maps

        var purchasedNFT : NFTActorClass.NFT = switch (mapOfNFTs.get(id)) { // get the sold NFT's Id
            case null return "NFT dose not exist.";
            case (?result) result;
        };

        let transferResult = await purchasedNFT.transferOwnership(newOwnerId); // transfer ownership
        if (transferResult == "Success") {
            mapOfListings.delete(id); // delete NFT from ListingMap
            var ownedNFTs : List.List<Principal> = switch (mapOfOwners.get(ownerId)) { // get the owner's NFT list
                case null List.nil<Principal>();
                case (?result) result;
            };
            ownedNFTs := List.filter(ownedNFTs, func (listItemId: Principal) : Bool { // delete the NFT from the list
                return listItemId != id;
            });
            addToOwnerMap(newOwnerId, id); // save the NFT to new owner
            return "Success";
        } else {
            return transferResult;
        }
    };
};
