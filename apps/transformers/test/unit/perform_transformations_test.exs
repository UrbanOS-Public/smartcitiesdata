# Tests to write?:

# when given a list of transformations, returns a function that calls all
#   each transform function in order

# when one transform function fails in the sequence, the result
#   of the constructTransformation is a function that returns {:error, reason}

# Notes for how to use this in alchemist:

# in broadway:
# [SC_Transformations] -> map (atom, params) -> FunctionBuilder.build(atom, params) -> [operation1, op2, op3] (opsList)

# that result, opsList, goes onto the context for handle message to call
