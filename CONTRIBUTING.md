# Contributing to Biome.jl

**Thank you for your interest in contributing to Biome.jl!**

We welcome all kinds of contributions, from bug reports and documentation improvements to new features and Plant Functional Type (PFT) definitions.

## Table of Contents

- [Ways to Contribute](#ways-to-contribute)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Contributing PFTs](#contributing-pfts)
- [Code Style Guidelines](#code-style-guidelines)
- [Documentation](#documentation)
- [Submitting Issues](#submitting-issues)
- [Pull Request Process](#pull-request-process)
- [Community Guidelines](#community-guidelines)

## Ways to Contribute

### Bug Reports
- Report bugs and unexpected behavior
- Provide reproducible examples
- Help improve error messages and diagnostics

### Documentation  
- Fix typos and improve clarity
- Add examples and tutorials
- Improve API documentation

### Testing
- Add test cases for edge conditions
- Improve test coverage
- Performance benchmarking
- Cross-platform testing

### Plant Functional Types (PFTs)
- Add new PFT definitions for specific regions or ecosystems
- Improve existing PFT parameterizations
- Validate PFT performance against observations

### New Features
- Implement new biome classification schemes
- Improve or add new physiological modules (CO2 response, nutrient cycling)
- Add climate data processing utilities
- Enhance performance and scalability

### Model Validation
- Compare model outputs with observations
- Improve model accuracy and reliability
- Add benchmarking datasets

## Getting Started

### Prerequisites

- Julia 1.6 or higher
- Git
- Basic familiarity with Julia and climate modeling concepts

### Development Setup

1. **Fork and clone the repository**:
   ```bash
   git clone https://github.com/clechartre/Biome.jl.git
   cd Biome.jl
   ```

2. **Set up the development environment**:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   julia --project=. -e 'using Pkg; Pkg.develop(PackageSpec(path="."))'
   ```

3. **Run tests to ensure everything works**:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

4. **Start Julia with the project environment**:
   ```bash
   julia --project=.
   ```

## Development Workflow

### Branch Strategy

- `master`: Stable release branch
- `develop`: Integration branch for new features  
- `feature/description`: Feature development branches
- `bugfix/description`: Bug fix branches
- `hotfix/description`: Critical fixes for releases

### Typical Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write code following our style guidelines
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

4. **Commit and push**:
   ```bash
   git add .
   git commit -m "Add: brief description of changes"
   git push origin feature/your-feature-name
   ```

5. **Open a Pull Request** on GitHub

## Testing

### Running Tests

```bash
# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run tests with coverage
julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'

# Run specific test file
julia --project=. test/test_specific_module.jl
```

### Test Structure

- `test/runtests.jl`: Main test runner
- `test/test_BIOME/`: Module-specific tests
- Tests should be fast, isolated, and deterministic
- Include both unit tests and integration tests

### Writing Tests

```julia
@testset "Your Feature Tests" begin
    @test your_function(input) == expected_output
    @test_throws ErrorType your_function(bad_input)
    @test your_function(input) ≈ expected_float atol=1e-10
end
```

## Contributing PFTs

Plant Functional Types are a key component of Biome.jl. We encourage contributions of new PFT definitions!

### PFT Contribution Guidelines

1. **Research-based**: PFTs should be based on published literature or field observations
2. **Well-documented**: Include references and rationale for parameter choices
3. **Tested**: Provide validation against known vegetation patterns
4. **Regional relevance**: Especially valuable for underrepresented regions

### PFT Submission Process

1. Create a new file in `src/models/pfts/` following existing examples
2. Include comprehensive documentation with references
3. Add tests in `test/test_BIOME/test_pfts.jl`
4. Update the PFT catalog documentation
5. Submit a pull request with validation results

### Example PFT Definition

```julia
"""
Mediterranean Shrubland PFT

Based on XXX et al. (XXXX) and field observations from...
References:
"""
struct MediterraneanShrubPFT <: AbstractPFT

# Default constructor with literature-based parameters
MediterraneanShrubPFT() = MediterraneanShrubPFT(
   constraints = (
    gdd5 = [800.0, 2500.0],    # GDD5 range
    tcm = [0.0, 18.0],        # TCM range  
    gsp = [200.0, 600.0]      # Some new constraint: GSP range
)
```

## Code Style Guidelines

### Julia Style

- Follow [Blue Style](https://github.com/invenia/BlueStyle) conventions
- Use descriptive variable names (`temperature_celsius` not `t`)
- Include docstrings for all public functions
- Keep functions focused and small when possible
- Use type annotations for clarity

### Example Function

```julia
"""
    calculate_growing_degree_days(temperature::Vector{Float64}, base_temp::Float64=5.0)

Calculate growing degree days from monthly temperature data.

# Arguments
- `temperature`: Vector of monthly temperatures (°C)
- `base_temp`: Base temperature threshold (°C, default: 5.0)

# Returns
- `Float64`: Total growing degree days

# Example
```julia
temps = [2.0, 4.0, 8.0, 12.0, 16.0, 20.0, 22.0, 21.0, 17.0, 11.0, 6.0, 3.0]
gdd = calculate_growing_degree_days(temps)
```
"""
function calculate_growing_degree_days(temperature::Vector{Float64}, base_temp::Float64=5.0)
    # Implementation here
    return sum(max.(temperature .- base_temp, 0.0)) * 30.44  # Approximate days per month
end
```

### File Organization

- One type/major function per file when possible
- Group related functionality together
- Use clear, descriptive filenames
- Include file-level documentation

## Documentation

### Building Documentation Locally

```bash
julia --project=docs/ -e 'using Pkg; Pkg.instantiate()'
julia --project=docs/ docs/make.jl
```

### Documentation Guidelines

- Write docstrings for all exported functions
- Include examples in docstrings
- Use clear, concise language
- Add new pages to `docs/src/` for major features
- Update the documentation index when adding new content

## Submitting Issues

Before submitting a new issue, please:

1. **Search existing issues** to avoid duplicates
2. **Use the issue template** if available
3. **Provide a minimal reproducible example**
4. **Include system information** (Julia version, OS, package versions)

### Bug Report Template

```markdown
**Biome.jl version**: 
**Julia version**: 
**Operating System**: 

**Description**
A clear description of what the bug is.

**Minimal Reproducible Example**
```julia
# Code that reproduces the issue
```

**Expected behavior**
What you expected to happen.

**Actual behavior**  
What actually happened.

**Additional context**
Any other relevant information.

## Pull Request Process

1. **Create a focused PR**: One feature or fix per PR
2. **Write a clear title and description**: Explain what and why
3. **Update tests**: Add tests for new functionality
4. **Update documentation**: Document user-facing changes
5. **Check CI**: Ensure all tests pass
6. **Respond to reviews**: Address feedback promptly and professionally

### PR Checklist

- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] Code follows style guidelines  
- [ ] No breaking changes (or clearly documented)
- [ ] Linear git history (rebase if needed)
- [ ] Descriptive commit messages

### Commit Message Format

```
Type: Brief description (50 chars max)

More detailed explanation if needed. Wrap at 72 characters.

- List any breaking changes
- Reference issues with #issue-number
```

Types: `Add`, `Fix`, `Update`, `Remove`, `Refactor`, `Doc`, `Test`

## Community Guidelines

### Code of Conduct

We are committed to providing a welcoming and inclusive environment:

- **Be respectful**: Treat everyone with respect and kindness
- **Be constructive**: Focus on the work and provide helpful feedback  
- **Be patient**: Remember that contributors have varying experience levels
- **Be collaborative**: We're all working toward the same goals

### Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion  
- **Email**: capucine.lechartre@wsl.ch for sensitive issues

## Recognition

Contributors are recognized in:

- The `AUTHORS.md` file
- Release notes for significant contributions
- The project documentation
- Special recognition for major PFT contributions

## Additional Resources

- [Julia Documentation](https://docs.julialang.org/)
- [Original BIOME4 Model](https://github.com/jedokaplan/BIOME4)
- [Climate Data Sources](https://chelsa-climate.org/)
- [Plant Functional Type Concepts](https://doi.org/10.1111/j.1365-2486.2007.01364.x)

---

Every contribution, no matter how small, helps make Biome.jl better for the entire community. Thank you for taking the time to contribute!
