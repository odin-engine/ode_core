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
// Dense_Arr -- tail swap unordered dense preallocated array. 
// 
// Use it when order doesn't matter but iteration speed does. 
// When item is removed it is replaced with tail item and count decresed by one.
// Has no empty (nil) items.
// Why not use [dynamic] array? Because we want full control over 
// memory allocations and what operations are allowed.

    Dense_Arr :: struct($T: typeid) {
        cap: int, 
        items: []T,
    }

    dense_arr__init :: proc(self: ^Dense_Arr($T), cap: int, allocator: runtime.Allocator) -> runtime.Allocator_Error {
        err: runtime.Allocator_Error = runtime.Allocator_Error.None
        self.items, err = make([]T, cap, allocator)
        ((^runtime.Raw_Slice)(&self.items)).len = 0
        self.cap = cap
        return err
    }

    dense_arr__terminate :: proc(self: ^Dense_Arr($T), allocator: runtime.Allocator) -> runtime.Allocator_Error {
        self.cap = 0
        ((^runtime.Raw_Slice)(&self.items)).len = 0
        return delete(self.items, allocator)
    }

    // `dense_arr__remove_by_index` removes the element at the specified `index`. 
    // 
    // Note: Similar to unordered_remove() for dynamic arrays but this is not a dynamic array.
    dense_arr__remove_by_index :: proc(self: ^Dense_Arr($T), #any_int index: int, loc := #caller_location) #no_bounds_check {
        raw := (^runtime.Raw_Slice)(&self.items)
        runtime.bounds_check_error_loc(loc, index, raw.len)

        n := raw.len - 1
        if index != n {
            // COPY
            self.items[index] = self.items[n]
        }
        raw.len -= 1
    }

    dense_arr__remove_by_value :: proc(self: ^Dense_Arr($T), value: T, loc := #caller_location) -> Core_Error {
        raw := (^runtime.Raw_Slice)(&self.items)
        for index:= 0; index < raw.len; index += 1 {
            if self.items[index] == value {
                dense_arr__remove_by_index(self, index, loc)
                return Core_Error.None
            }
        }

        return Core_Error.Not_Found
    }

    dense_arr__add :: proc(self: ^Dense_Arr($T), value: T) -> (int, Core_Error) #no_bounds_check {
        raw := (^runtime.Raw_Slice)(&self.items)
        if raw.len >= self.cap do return DELETED_INDEX, Core_Error.Container_Is_Full

        index := raw.len
        self.items[index] = value
        raw.len += 1

        return index, Core_Error.None
    }

    dense_arr__len :: #force_inline proc(self: ^Dense_Arr($T)) -> int {
        return ((^runtime.Raw_Slice)(&self.items)).len
    }

    dense_arr__memory_usage :: proc (self: ^Dense_Arr($T)) -> int {
        total := size_of(self^)

        if self.items != nil {
            total += size_of(self.items[0]) * self.cap
        }

        return total
    }

    dense_arr__zero :: proc (self: ^Dense_Arr($T)) {
        assert(self.items != nil)

        mem.zero(raw_data(self.items), size_of(T) * self.cap)
    } 

    dense_arr__clear :: dense_arr__zero