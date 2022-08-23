### ==================================
###          HYPERION INTERFACE
### ==================================

%lang starknet

### ========== dependencies ==========

@contract_interface
namespace IHyperion: 
 
    func get_token(token_index : felt) -> (token_address : felt):
    end

    func exchange(i : felt, j : felt, _dx : felt) -> (res : felt, a : felt, b : felt):
    end
end








