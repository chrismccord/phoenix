Code.require_file("./support/code_generator_case.exs", __DIR__)

# Compile installer app up front so multiple test cases
# don't try to compile it at the same time.
Phoenix.Integration.CodeGeneratorCase.mix_run!(["do", "deps.get,", "compile"], "./installer")

ExUnit.configure(max_cases: 2, timeout: 180_000)
ExUnit.start()
