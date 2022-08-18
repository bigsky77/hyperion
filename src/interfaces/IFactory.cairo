### ==================================
###          FACTORY INTERFACE
### ==================================

%lang starknet

### ========== dependencies ==========

@contract_interface
namespace IFactory: 
 
    func create_pool(tokens_len : felt, tokens : felt*) -> (pool_address : felt):
    end
end









