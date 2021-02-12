
"""
"""
abstract type AssemblyStrategy end

"""
"""
function row_map(a::AssemblyStrategy,row)
  @abstractmethod
end

"""
"""
function col_map(a::AssemblyStrategy,col)
  @abstractmethod
end

"""
"""
function row_mask(a::AssemblyStrategy,row)
  @abstractmethod
end

"""
"""
function col_mask(a::AssemblyStrategy,col)
  @abstractmethod
end

struct DefaultAssemblyStrategy <: AssemblyStrategy end

row_map(a::DefaultAssemblyStrategy,row) = row

col_map(a::DefaultAssemblyStrategy,col) = col

row_mask(a::DefaultAssemblyStrategy,row) = true

col_mask(a::DefaultAssemblyStrategy,col) = true

"""
"""
abstract type Assembler <: GridapType end

"""
"""
function get_rows(a::Assembler)
  @abstractmethod
end

"""
"""
function get_cols(a::Assembler)
  @abstractmethod
end

num_rows(a::Assembler) = length(get_rows(a))
num_cols(a::Assembler) = length(get_cols(a))

Base.axes(a::Assembler) = (get_rows(a),get_cols(a))
Base.size(a::Assembler) = (num_rows(a),num_cols(a))

"""
"""
function get_assembly_strategy(a::Assembler)
  @abstractmethod
end

"""
"""
function allocate_matrix(a::Assembler,matdata)
  @abstractmethod
end

"""
"""
function allocate_vector(a::Assembler,vecdata)
  @abstractmethod
end

"""
"""
function allocate_matrix_and_vector(a::Assembler,data)
  @abstractmethod
end

"""
"""
function assemble_matrix!(A,a::Assembler,matdata)
  @abstractmethod
end

"""
"""
function assemble_matrix_add!(mat,a::Assembler, matdata)
  @abstractmethod
end

"""
"""
function assemble_vector!(b,a::Assembler,vecdata)
  @abstractmethod
end

"""
"""
function assemble_vector_add!(b,a::Assembler,vecdata)
  @abstractmethod
end

"""
"""
function assemble_matrix_and_vector!(A,b,a::Assembler, data)
  @abstractmethod
end

function assemble_matrix_and_vector_add!(A,b,a::Assembler, data)
  @abstractmethod
end

"""
"""
function assemble_matrix(a::Assembler,matdata)
  A = allocate_matrix(a,matdata)
  assemble_matrix!(A,a,matdata)
  A
end

"""
"""
function assemble_vector(a::Assembler,vecdata)
  b = allocate_vector(a,vecdata)
  assemble_vector!(b,a,vecdata)
  b
end

"""
"""
function assemble_matrix_and_vector(a::Assembler,data)
  A, b = allocate_matrix_and_vector(a,data)
  assemble_matrix_and_vector!(A,b,a,data)
  (A, b)
end

"""
"""
function test_assembler(a::Assembler,matdata,vecdata,data)
  A = allocate_matrix(a,matdata)
  @test num_cols(a) == size(A,2)
  @test num_rows(a) == size(A,1)
  assemble_matrix!(A,a,matdata)
  assemble_matrix_add!(A,a,matdata)
  A = assemble_matrix(a,matdata)
  @test num_cols(a) == size(A,2)
  @test num_rows(a) == size(A,1)
  b = allocate_vector(a,vecdata)
  @test num_rows(a) == length(b)
  assemble_vector!(b,a,vecdata)
  assemble_vector_add!(b,a,vecdata)
  b = assemble_vector(a,vecdata)
  @test num_rows(a) == length(b)
  A, b = allocate_matrix_and_vector(a,data)
  assemble_matrix_and_vector!(A,b,a,data)
  assemble_matrix_and_vector_add!(A,b,a,data)
  @test num_cols(a) == size(A,2)
  @test num_rows(a) == size(A,1)
  @test num_rows(a) == length(b)
  A, b = assemble_matrix_and_vector(a,data)
  @test num_cols(a) == size(A,2)
  @test num_rows(a) == size(A,1)
  @test num_rows(a) == length(b)
end

# Some syntactic sugar for assembling from anonymous functions
# and objects from which one can collect cell matrices/vectors

function assemble_matrix(f::Function,a::Assembler,U::FESpace,V::FESpace)
  v = get_cell_shapefuns(V)
  u = get_cell_shapefuns_trial(U)
  assemble_matrix(a,collect_cell_matrix(U,V,f(u,v)))
end

function assemble_vector(f::Function,a::Assembler,V::FESpace)
  v = get_cell_shapefuns(V)
  assemble_vector(a,collect_cell_vector(V,f(v)))
end

function assemble_matrix_and_vector(f::Function,b::Function,a::Assembler,U::FESpace,V::FESpace)
  v = get_cell_shapefuns(V)
  u = get_cell_shapefuns_trial(U)
  assemble_matrix_and_vector(a,collect_cell_matrix_and_vector(U,V,f(u,v),b(v)))
end

function assemble_matrix(f,a::Assembler,U::FESpace,V::FESpace)
  assemble_matrix(a,collect_cell_matrix(U,V,f))
end

function assemble_vector(f,a::Assembler,V::FESpace)
  assemble_vector(a,collect_cell_vector(V,f))
end

function assemble_matrix_and_vector(f,b,a::Assembler,U::FESpace,V::FESpace)
  assemble_matrix_and_vector(a,collect_cell_matrix_and_vector(U,V,f,b))
end

function assemble_matrix(f,U::FESpace,V::FESpace)
  a = SparseMatrixAssembler(U,V)
  assemble_matrix(f,a,U,V)
end

function assemble_vector(f,V::FESpace)
  a = SparseMatrixAssembler(V,V)
  assemble_vector(f,a,V)
end

function assemble_matrix_and_vector(f,b,U::FESpace,V::FESpace)
  a = SparseMatrixAssembler(U,V)
  assemble_matrix_and_vector(f,b,a,U,V)
end

# Abstract interface for computing the data to be sent to the assembler

function collect_cell_matrix(trial::FESpace,test::FESpace,mat_contributions)
  @abstractmethod
end

function collect_cell_vector(test::FESpace,vec_contributions)
  @abstractmethod
end

function collect_cell_matrix_and_vector(
  trial::FESpace,test::FESpace,mat_contributions,vec_contributions)
  @abstractmethod
end

function collect_cell_matrix_and_vector(
  trial::FESpace,test::FESpace,mat_contributions,vec_contributions,uhd::FEFunction)
  @abstractmethod
end

# Implementation of this interface for DomainContribution

function collect_cell_matrix(trial::FESpace,test::FESpace,a::DomainContribution)
  w = []
  r = []
  c = []
  for trian in get_domains(a)
    cell_mat = get_contribution(a,trian)
    @assert eltype(cell_mat) <: AbstractMatrix
    cell_mat_c = attach_constraints_cols(trial,cell_mat,trian)
    cell_mat_rc = attach_constraints_rows(test,cell_mat_c,trian)
    rows = get_cell_dof_ids(test,trian)
    cols = get_cell_dof_ids(trial,trian)
    push!(w,cell_mat_rc)
    push!(r,rows)
    push!(c,cols)
  end
  (w,r,c)
end

function collect_cell_vector(test::FESpace,a::DomainContribution)
  w = []
  r = []
  for trian in get_domains(a)
    cell_vec = get_contribution(a,trian)
    @assert eltype(cell_vec) <: AbstractVector
    cell_vec_r = attach_constraints_rows(test,cell_vec,trian)
    rows = get_cell_dof_ids(test,trian)
    push!(w,cell_vec_r)
    push!(r,rows)
  end
  (w,r)
end

function _collect_cell_matvec(trial::FESpace,test::FESpace,a::DomainContribution)
  w = []
  r = []
  c = []
  for trian in get_domains(a)
    cell_mat = get_contribution(a,trian)
    @assert eltype(cell_mat) <: Tuple
    cell_mat_c = attach_constraints_cols(trial,cell_mat,trian)
    cell_mat_rc = attach_constraints_rows(test,cell_mat_c,trian)
    rows = get_cell_dof_ids(test,trian)
    cols = get_cell_dof_ids(trial,trian)
    push!(w,cell_mat_rc)
    push!(r,rows)
    push!(c,cols)
  end
  (w,r,c)
end

function collect_cell_matrix_and_vector(
  trial::FESpace,test::FESpace,
  biform::DomainContribution,liform::DomainContribution)

  matvec, mat, vec = _pair_contribution_when_possible(biform,liform)
  matvecdata = _collect_cell_matvec(trial,test,matvec)
  matdata = collect_cell_matrix(trial,test,mat)
  vecdata = collect_cell_vector(test,vec)
  (matvecdata, matdata, vecdata)
end

function collect_cell_matrix_and_vector(
  trial::FESpace,test::FESpace,
  biform::DomainContribution,liform::DomainContribution,uhd::FEFunction)

  matvec, mat, vec = _pair_contribution_when_possible(biform,liform,uhd)

  matvecdata = _collect_cell_matvec(trial,test,matvec)
  matdata = collect_cell_matrix(trial,test,mat)
  vecdata = collect_cell_vector(test,vec)
  (matvecdata, matdata, vecdata)
end

function _pair_contribution_when_possible(biform,liform)
  matvec = DomainContribution()
  mat = DomainContribution()
  vec = DomainContribution()
  for (trian,t) in biform.dict
    if haskey(liform.dict,trian)
      matvec.dict[trian] = pair_arrays(t,liform.dict[trian])
    else
      mat.dict[trian] = t
    end
  end
  for (trian,t) in liform.dict
    if ! haskey(biform.dict,trian)
      vec.dict[trian] = t
    end
  end
  matvec, mat, vec
end

function _pair_contribution_when_possible(biform,liform,uhd)
  _matvec, _mat, _vec = _pair_contribution_when_possible(biform,liform)
  matvec = DomainContribution()
  mat = DomainContribution()
  for (trian,t) in _matvec.dict
    cellvals = get_cell_dof_values(uhd,get_cell_to_bgcell(trian))
    matvec.dict[trian] = attach_dirichlet(t,cellvals)
  end
  for (trian,t) in _mat.dict
    cellvals = get_cell_dof_values(uhd,get_cell_to_bgcell(trian))
    matvec.dict[trian] = attach_dirichlet(t,cellvals)
  end
  matvec, mat, _vec
end

# allow linear forms like `l(v) = 0

function collect_cell_vector(test::FESpace,l::Number)
  @notimplementedif l != 0
  w = []
  r = []
  (w,r)
end

function collect_cell_matrix_and_vector(
  trial::FESpace,test::FESpace,mat_contributions::DomainContribution,l::Number)
  @notimplementedif l != 0
  vec_contributions = DomainContribution()
  collect_cell_matrix_and_vector(test,trial,mat_contributions,vec_contributions)
end

function collect_cell_matrix_and_vector(
  trial::FESpace,test::FESpace,biform::DomainContribution,l::Number,uhd::FEFunction)
  liform = DomainContribution()
  collect_cell_matrix_and_vector(test,trial,biform,liform,uhd)
end
