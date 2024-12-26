/*
    2025 (c) Oleh, https://github.com/zm69
*/
package ode_core

// Base
    import "base:runtime"

// Core
    import "core:log"
    import "core:mem"

///////////////////////////////////////////////////////////////////////////////
// ix_gen -- index + generation 
// When we reuse id (because old entity was destroyed) we increase generation. 
// In this way if you saved old id, even though their ix will be the same their gen will be different.

    GEN_MAX :: 255

    ix_gen :: bit_field i64 {
        ix: int | 56,       // index
        gen: uint | 8,      // generation
    }

    Ix_Gen_Factory :: struct {
        created_count: int,
        
        cap: int, 
        items: []ix_gen,

        freed: []int,
        freed_count: int
    }

    ix_gen_factory__init :: proc(self: ^Ix_Gen_Factory, cap: int, allocator: runtime.Allocator) -> runtime.Allocator_Error {
        self.cap = cap

        self.items = make([]ix_gen, cap, allocator) or_return
        self.freed = make([]int, cap, allocator) or_return 
        ix_gen_factory__clear(self)

        return runtime.Allocator_Error.None
    }
    
    ix_gen_factory__terminate :: proc(self: ^Ix_Gen_Factory, allocator: runtime.Allocator) -> runtime.Allocator_Error {
        self.cap = 0
        self.created_count = 0
        self.freed_count = 0
        delete(self.freed, allocator) or_return
        return delete(self.items, allocator)
    }

    @(require_results)
    ix_gen_factory__new_id :: proc(self: ^Ix_Gen_Factory) -> (ix_gen, Core_Error) {
        id: ix_gen 
        p: ^ix_gen
        ix: int
        if self.freed_count > 0 {
            // reuse freed id
            self.freed_count -= 1 
            ix = self.freed[self.freed_count]
            self.freed[self.freed_count] = DELETED_INDEX

            p = &self.items[ix]
        
            assert(p.ix == DELETED_INDEX) // sanity check
            p.ix = ix
            p.gen = p.gen >= GEN_MAX ? 0 : p.gen + 1

            id = p^
        } else {
            if self.created_count >= self.cap {
                id.ix = DELETED_INDEX
                id.gen = 0
                return id, Core_Error.Container_Is_Full
            }

            p = &self.items[self.created_count]
            assert(p.ix == DELETED_INDEX) // sanity check
            p.ix = self.created_count

            id = p^
            
            self.created_count += 1
        }

        return id, Core_Error.None
    }

    ix_gen_factory__free_id :: proc(self: ^Ix_Gen_Factory, id: ix_gen) -> Core_Error {
        if self.freed_count >= self.cap do return Core_Error.Container_Is_Full
        if id.ix < 0 || id.ix >= self.cap do return Core_Error.Out_Of_Bounds
        if self.items[id.ix].ix == DELETED_INDEX do return Core_Error.Already_Freed
        if self.items[id.ix] != id do return Core_Error.Not_Found
        
        self.items[id.ix].ix = DELETED_INDEX
        self.freed[self.freed_count] = id.ix
        self.freed_count += 1

        return Core_Error.None
    }

    ix_gen_factory__get_id :: #force_inline proc "contextless" (self: ^Ix_Gen_Factory, #any_int index: int, loc := #caller_location) -> ix_gen {
        runtime.bounds_check_error_loc(loc, index, self.cap)
    
        return self.items[index]
    }

    ix_gen_factory__is_freed :: #force_inline proc(self: ^Ix_Gen_Factory, id: ix_gen) -> bool {
        return self.items[id.ix].ix == DELETED_INDEX 
    }

    ix_gen_factory__is_expired :: #force_inline proc "contextless" (self: ^Ix_Gen_Factory, id: ix_gen) -> bool {
        return self.items[id.ix].gen != id.gen
    }

    @(require_results)
    ix_gen_factory__len :: #force_inline proc "contextless" (self: ^Ix_Gen_Factory) -> int {
        return self.created_count - self.freed_count
    }

    // in bytes
    ix_gen_factory__memory_usage :: proc(self: ^Ix_Gen_Factory) -> int {
        total := size_of(self^)
        if self.items != nil {
            total += size_of(self.items[0]) * self.cap
        }

        if self.freed != nil {
            total += size_of(self.freed[0]) * self.cap
        }
        
        return total
    }

    ix_gen_factory__clear :: proc(self: ^Ix_Gen_Factory) {
        assert(self != nil)
        assert(self.items != nil)
        assert(self.freed != nil)

        self.created_count = 0
        self.freed_count = 0
        for &item in self.items do item.ix = DELETED_INDEX
        for i:=0; i < self.cap; i+=1 do self.freed[i] = DELETED_INDEX

    }