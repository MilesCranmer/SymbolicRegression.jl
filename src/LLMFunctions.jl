module LLMFunctionsModule

using Random: default_rng, AbstractRNG, rand, randperm
using DynamicExpressions:
    Node,
    AbstractExpressionNode,
    AbstractExpression,
    ParametricExpression,
    ParametricNode,
    AbstractNode,
    NodeSampler,
    get_contents,
    with_contents,
    constructorof,
    copy_node,
    set_node!,
    count_nodes,
    has_constants,
    has_operators,
    string_tree,
    AbstractOperatorEnum
using Compat: Returns, @inline
using ..CoreModule: Options, DATA_TYPE, binopmap, unaopmap, LLMOptions
using ..MutationFunctionsModule: gen_random_tree_fixed_size

using PromptingTools:
    SystemMessage,
    UserMessage,
    AIMessage,
    aigenerate,
    CustomOpenAISchema,
    OllamaSchema,
    OpenAISchema
using JSON: parse

"""LLM Recoder records the LLM calls for debugging purposes."""
function llm_recorder(options::LLMOptions, expr::String, mode::String="debug")
    if options.active
        if !isdir(options.llm_recorder_dir)
            mkdir(options.llm_recorder_dir)
        end
        recorder = open(joinpath(options.llm_recorder_dir, "llm_calls.txt"), "a")
        write(recorder, string("[", mode, "] ", expr, "\n[/", mode, "]\n"))
        close(recorder)
    end
end

function load_prompt(path::String)::String
    # load prompt file 
    f = open(path, "r")
    s = read(f, String)
    close(f)
    return s
end

function convertDict(d)::NamedTuple
    return (; Dict(Symbol(k) => v for (k, v) in d)...)
end

function get_vars(options::Options)::String
    variable_names = ["x", "y", "z", "k", "j", "l", "m", "n", "p", "a", "b"]
    if !isnothing(options.llm_options.var_order)
        variable_names = [
            options.llm_options.var_order[key] for
            key in sort(collect(keys(options.llm_options.var_order)))
        ]
    end
    return join(variable_names, ", ")
end

function get_ops(options::Options)::String
    binary_operators = map(v -> string(v), map(binopmap, options.operators.binops))
    unary_operators = map(v -> string(v), map(unaopmap, options.operators.unaops))
    # Binary Ops: +, *, -, /, safe_pow (^)
    # Unary Ops: exp, safe_log, safe_sqrt, sin, cos
    return replace(
        replace(
            "binary operators: " *
            join(binary_operators, ", ") *
            ", and unary operators: " *
            join(unary_operators, ", "),
            "safe_" => "",
        ),
        "pow" => "^",
    )
end

"""
Constructs a prompt by replacing the element_id_tag with the corresponding element in the element_list.
If the element_list is longer than the number of occurrences of the element_id_tag, the missing elements are added after the last occurrence.
If the element_list is shorter than the number of occurrences of the element_id_tag, the extra ids are removed.
"""
function construct_prompt(
    user_prompt::String, element_list::Vector, element_id_tag::String
)::String
    # Split the user prompt into lines
    lines = split(user_prompt, "\n")

    # Filter lines that match the pattern "... : {{element_id_tag[1-9]}}
    pattern = r"^.*: \{\{" * element_id_tag * r"\d+\}\}$"

    # find all occurrences of the element_id_tag
    n_occurrences = count(x -> occursin(pattern, x), lines)

    # if n_occurrences is less than |element_list|, add the missing elements after the last occurrence
    if n_occurrences < length(element_list)
        last_occurrence = findlast(x -> occursin(pattern, x), lines)
        for i in reverse((n_occurrences + 1):length(element_list))
            new_line = replace(lines[last_occurrence], string(n_occurrences) => string(i))
            insert!(lines, last_occurrence + 1, new_line)
        end
    end

    new_prompt = ""
    idx = 1
    for line in lines
        # if the line matches the pattern
        if occursin(pattern, line)
            if idx > length(element_list)
                continue
            end
            # replace the element_id_tag with the corresponding element
            new_prompt *=
                replace(line, r"\{\{" * element_id_tag * r"\d+\}\}" => element_list[idx]) *
                "\n"
            idx += 1
        else
            new_prompt *= line * "\n"
        end
    end
    return new_prompt
end

function gen_llm_random_tree(
    node_count::Int,
    options::Options,
    nfeatures::Int,
    ::Type{T},
    idea_database::Union{Vector{String},Nothing},
)::AbstractExpressionNode{T} where {T<:DATA_TYPE}
    # Note that this base tree is just a placeholder; it will be replaced.
    N = 5
    # LLM prompt
    # conversation = [
    #     SystemMessage(load_prompt(options.llm_options.prompts_dir * "gen_random_system.txt")),
    #     UserMessage(load_prompt(options.llm_options.prompts_dir * "gen_random_user.txt"))]
    assumptions = sample_context(
        idea_database,
        options.llm_options.num_pareto_context,
        options.llm_options.idea_threshold,
    )

    if !options.llm_options.prompt_concepts
        assumptions = []
    end

    conversation = [
        UserMessage(
            load_prompt(options.llm_options.prompts_dir * "gen_random_system.txt") *
            "\n" *
            construct_prompt(
                load_prompt(options.llm_options.prompts_dir * "gen_random_user.txt"),
                assumptions,
                "assump",
            ),
        ),
    ]
    llm_recorder(options.llm_options, conversation[1].content, "llm_input|gen_random")

    if options.llm_options.llm_context != ""
        pushfirst!(assumptions, options.llm_options.llm_context)
    end

    msg = nothing
    try
        msg = aigenerate(
            CustomOpenAISchema(),
            conversation; #OllamaSchema(), conversation;
            variables=get_vars(options),
            operators=get_ops(options),
            N=N,
            api_key=options.llm_options.api_key,
            model=options.llm_options.model,
            api_kwargs=convertDict(options.llm_options.api_kwargs),
            http_kwargs=convertDict(options.llm_options.http_kwargs),
        )
    catch e
        llm_recorder(options.llm_options, "None", "gen_random|failed")
        return gen_random_tree_fixed_size(node_count, options, nfeatures, T)
    end
    llm_recorder(options.llm_options, string(msg.content), "llm_output|gen_random")

    gen_tree_options = parse_msg_content(msg.content)

    N = min(size(gen_tree_options)[1], N)

    if N == 0
        llm_recorder(options.llm_options, "None", "gen_random|failed")
        return gen_random_tree_fixed_size(node_count, options, nfeatures, T)
    end

    for i in 1:N
        l = rand(1:N)
        t = expr_to_tree(
            T,
            String(strip(gen_tree_options[l], [' ', '\n', '"', ',', '.', '[', ']'])),
            options,
        )
        if t.val == 1 && t.constant
            continue
        end
        llm_recorder(options.llm_options, tree_to_expr(t, options), "gen_random")

        return t
    end

    out = expr_to_tree(
        T, String(strip(gen_tree_options[1], [' ', '\n', '"', ',', '.', '[', ']'])), options
    )

    llm_recorder(options.llm_options, tree_to_expr(out, options), "gen_random")

    if out.val == 1 && out.constant
        return gen_random_tree_fixed_size(node_count, options, nfeatures, T)
    end

    return out
end

"""Crossover between two expressions"""
function crossover_trees(
    tree1::AbstractExpressionNode{T}, tree2::AbstractExpressionNode{T}
)::Tuple{AbstractExpressionNode{T},AbstractExpressionNode{T}} where {T<:DATA_TYPE}
    tree1 = copy_node(tree1)
    tree2 = copy_node(tree2)

    node1, parent1, side1 = random_node_and_parent(tree1)
    node2, parent2, side2 = random_node_and_parent(tree2)

    node1 = copy_node(node1)

    if side1 == 'l'
        parent1.l = copy_node(node2)
        # tree1 now contains this.
    elseif side1 == 'r'
        parent1.r = copy_node(node2)
        # tree1 now contains this.
    else # 'n'
        # This means that there is no parent2.
        tree1 = copy_node(node2)
    end

    if side2 == 'l'
        parent2.l = node1
    elseif side2 == 'r'
        parent2.r = node1
    else # 'n'
        tree2 = node1
    end
    return tree1, tree2
end

function sketch_const(val)
    does_not_need_brackets = (typeof(val) <: Union{Real,AbstractArray})

    if does_not_need_brackets
        if isinteger(val) && (abs(val) < 5) # don't abstract integer constants from -4 to 4, useful for exponents
            string(val)
        else
            "C"
        end
    else
        if isinteger(val) && (abs(val) < 5) # don't abstract integer constants from -4 to 4, useful for exponents
            "(" * string(val) * ")"
        else
            "(C)"
        end
    end
end

function tree_to_expr(
    ex::AbstractExpression{T}, options::Options
)::String where {T<:DATA_TYPE}
    return tree_to_expr(get_contents(ex), options)
end

function tree_to_expr(tree::AbstractExpressionNode{T}, options)::String where {T<:DATA_TYPE}
    variable_names = ["x", "y", "z", "k", "j", "l", "m", "n", "p", "a", "b"]
    if !isnothing(options.llm_options.var_order)
        variable_names = [
            options.llm_options.var_order[key] for
            key in sort(collect(keys(options.llm_options.var_order)))
        ]
    end
    return string_tree(
        tree, options.operators; f_constant=sketch_const, variable_names=variable_names
    )
end

function handle_not_expr(::Type{T}, x, var_names)::Node{T} where {T<:DATA_TYPE}
    if x isa Real
        Node{T}(; val=convert(T, x)) # old:  Node(T, 0, true, convert(T,x))
    elseif x isa Symbol
        if x === :C # constant that got abstracted
            Node{T}(; val=convert(T, 1)) # old: Node(T, 0, true, convert(T,1))
        else
            feature = findfirst(isequal(string(x)), var_names)
            if isnothing(feature) # invalid var name, just assume its x0
                feature = 1
            end
            Node{T}(; feature=feature) # old: Node(T, 0, false, nothing, feature)
        end
    else
        Node{T}(; val=convert(T, 1)) # old: Node(T, 0, true, convert(T,1)) # return a constant being 0
    end
end

function expr_to_tree_recurse(
    ::Type{T}, node::Expr, op::AbstractOperatorEnum, var_names
)::Node{T} where {T<:DATA_TYPE}
    args = node.args
    x = args[1]
    degree = length(args)

    if degree == 1
        handle_not_expr(T, x, var_names)
    elseif degree == 2
        unary_operators = map(v -> string(v), map(unaopmap, op.unaops))
        idx = findfirst(isequal(string(x)), unary_operators)
        if isnothing(idx) # if not used operator, make it the first one
            idx = findfirst(isequal("safe_" * string(x)), unary_operators)
            if isnothing(idx)
                idx = 1
            end
        end

        left = if (args[2] isa Expr)
            expr_to_tree_recurse(T, args[2], op, var_names)
        else
            handle_not_expr(T, args[2], var_names)
        end

        Node(; op=idx, l=left) # old: Node(1, false, nothing, 0, idx, left)
    elseif degree == 3
        if x === :^
            x = :pow
        end
        binary_operators = map(v -> string(v), map(binopmap, op.binops))
        idx = findfirst(isequal(string(x)), binary_operators)
        if isnothing(idx) # if not used operator, make it the first one
            idx = findfirst(isequal("safe_" * string(x)), binary_operators)
            if isnothing(idx)
                idx = 1
            end
        end

        left = if (args[2] isa Expr)
            expr_to_tree_recurse(T, args[2], op, var_names)
        else
            handle_not_expr(T, args[2], var_names)
        end
        right = if (args[3] isa Expr)
            expr_to_tree_recurse(T, args[3], op, var_names)
        else
            handle_not_expr(T, args[3], var_names)
        end

        Node(; op=idx, l=left, r=right) # old: Node(2, false, nothing, 0, idx, left, right)
    else
        Node{T}(; val=convert(T, 1))  # old: Node(T, 0, true, convert(T,1)) # return a constant being 1
    end
end

function expr_to_tree_run(::Type{T}, x::String, options)::Node{T} where {T<:DATA_TYPE}
    try
        expr = Meta.parse(x)
        variable_names = ["x", "y", "z", "k", "j", "l", "m", "n", "p", "a", "b"]
        if !isnothing(options.llm_options.var_order)
            variable_names = [
                options.llm_options.var_order[key] for
                key in sort(collect(keys(options.llm_options.var_order)))
            ]
        end
        if expr isa Expr
            expr_to_tree_recurse(T, expr, options.operators, variable_names)
        else
            handle_not_expr(T, expr, variable_names)
        end
    catch
        Node{T}(; val=convert(T, 1)) # old: Node(T, 0, true, convert(T,1)) # return a constant being 1
    end
end

function expr_to_tree(::Type{T}, x::String, options) where {T<:DATA_TYPE}
    if options.llm_options.is_parametric
        out = ParametricNode{T}(expr_to_tree_run(T, x, options))
    else
        out = Node{T}(expr_to_tree_run(T, x, options))
    end
    return out
end

function format_pareto(dominating, options, num_pareto_context::Int)::Vector{String}
    pareto = Vector{String}()
    if !isnothing(dominating) && size(dominating)[1] > 0
        idx = randperm(size(dominating)[1])
        for i in 1:min(size(dominating)[1], num_pareto_context)
            push!(pareto, tree_to_expr(dominating[idx[i]].tree, options))
        end
    end
    while size(pareto)[1] < num_pareto_context
        push!(pareto, "None")
    end
    return pareto
end

function sample_one_context(idea_database, idea_threshold)::String
    if isnothing(idea_database)
        return "None"
    end

    N = size(idea_database)[1]
    if N == 0
        return "None"
    end

    try
        idea_database[rand(1:min(idea_threshold, N))]
    catch e
        "None"
    end
end

function sample_context(idea_database, N, idea_threshold)::Vector{String}
    assumptions = Vector{String}()
    if isnothing(idea_database)
        for _ in 1:N
            push!(assumptions, "None")
        end
        return assumptions
    end

    if size(idea_database)[1] < N
        for i in 1:(size(idea_database)[1])
            push!(assumptions, idea_database[i])
        end
        for i in (size(idea_database)[1] + 1):N
            push!(assumptions, "None")
        end
        return assumptions
    end

    while size(assumptions)[1] < N
        chosen_idea = sample_one_context(idea_database, idea_threshold)
        if chosen_idea in assumptions
            continue
        end
        push!(assumptions, chosen_idea)
    end
    return assumptions
end

function prompt_evol(idea_database, options::Options)
    num_ideas = size(idea_database)[1]
    if num_ideas <= options.llm_options.idea_threshold
        return nothing
    end

    idea1 = idea_database[rand((options.llm_options.idea_threshold + 1):num_ideas)]
    idea2 = idea_database[rand((options.llm_options.idea_threshold + 1):num_ideas)] # they could be same (should be allowed)
    idea3 = idea_database[rand((options.llm_options.idea_threshold + 1):num_ideas)] # they could be same (should be allowed)
    idea4 = idea_database[rand((options.llm_options.idea_threshold + 1):num_ideas)] # they could be same (should be allowed)
    idea5 = idea_database[rand((options.llm_options.idea_threshold + 1):num_ideas)] # they could be same (should be allowed)

    N = 5

    # conversation = [
    #     SystemMessage(load_prompt(options.llm_options.prompts_dir * "prompt_evol_system.txt")),
    #     UserMessage(load_prompt(options.llm_options.prompts_dir * "prompt_evol_user.txt"))]
    conversation = [
        UserMessage(
            load_prompt(options.llm_options.prompts_dir * "prompt_evol_system.txt") *
            "\n" *
            construct_prompt(
                load_prompt(options.llm_options.prompts_dir * "prompt_evol_user.txt"),
                [idea1, idea2, idea3, idea4, idea5],
                "idea",
            ),
        ),
    ]
    llm_recorder(options.llm_options, conversation[1].content, "llm_input|ideas")

    msg = nothing
    try
        msg = aigenerate(
            CustomOpenAISchema(),
            conversation; #OllamaSchema(), conversation;
            N=N,
            api_key=options.llm_options.api_key,
            model=options.llm_options.model,
            api_kwargs=convertDict(options.llm_options.api_kwargs),
            http_kwargs=convertDict(options.llm_options.http_kwargs),
        )
    catch e
        llm_recorder(options.llm_options, "None", "ideas|failed")
        return nothing
    end
    llm_recorder(options.llm_options, string(msg.content), "llm_output|ideas")

    idea_options = parse_msg_content(msg.content)

    N = min(size(idea_options)[1], N)

    if N == 0
        llm_recorder(options.llm_options, "None", "ideas|failed")
        return nothing
    end

    # only choose one, merging ideas not really crossover
    chosen_idea = String(
        strip(idea_options[rand(1:N)], [' ', '\n', '"', ',', '.', '[', ']'])
    )

    llm_recorder(options.llm_options, chosen_idea, "ideas")

    return chosen_idea
end

function parse_msg_content(msg_content)
    content = msg_content
    try
        content = match(r"```json(.*?)```"s, msg_content).captures[1]
    catch e
        try
            content = match(r"```(.*?)```"s, msg_content).captures[1]
        catch e2
            try
                content = match(r"\[(.*?)\]"s, msg_content).match
            catch e3
                content = msg_content
            end
        end
    end

    try
        out = parse(content) # json parse
        if out isa Dict
            return [out[key] for key in keys(out)]
        end

        if out isa Vector && all(x -> isa(x, String), out)
            return out
        end
    catch e
        try
            content = strip(content, [' ', '\n', '"', ',', '.', '[', ']'])
            content = replace(content, "\n" => " ")
            out_list = split(content, "\", \"")
            return out_list
        catch e2
            return []
        end
    end

    try
        content = strip(content, [' ', '\n', '"', ',', '.', '[', ']'])
        content = replace(content, "\n" => " ")
        out_list = split(content, "\", \"")
        return out_list
    catch e3
        return []
    end
    # old method:
    # find first JSON list
    # first_idx = findfirst('[', content)
    # last_idx = findfirst(']', content)
    # content = chop(content, head=first_idx, tail=length(content) - last_idx + 1)

    # out_list = split(content, ",")
    # for i in 1:length(out_list)
    #     out_list[i] = replace(out_list[i], "//.*" => "") # filter comments
    # end

    # new method (for Llama since it follows directions better):
end

function update_idea_database(idea_database, dominating, worst_members, options::Options)
    # turn dominating pareto curve into ideas as strings
    if isnothing(dominating)
        return nothing
    end

    op = options.operators
    num_pareto_context = 5 # options.mutation_weights.num_pareto_context # must be 5 right now for prompts

    gexpr = format_pareto(dominating, options, num_pareto_context)
    bexpr = format_pareto(worst_members, options, num_pareto_context)

    N = 5

    # conversation = [
    #     SystemMessage(load_prompt(options.llm_options.prompts_dir * "extract_idea_system.txt")),
    #     UserMessage(load_prompt(options.llm_options.prompts_dir * "extract_idea_user.txt"))]
    conversation = [
        UserMessage(
            load_prompt(options.llm_options.prompts_dir * "extract_idea_system.txt") *
            "\n" *
            construct_prompt(
                construct_prompt(
                    load_prompt(options.llm_options.prompts_dir * "extract_idea_user.txt"),
                    gexpr,
                    "gexpr",
                ),
                bexpr,
                "bexpr",
            ),
        ),
    ]
    llm_recorder(options.llm_options, conversation[1].content, "llm_input|gen_random")

    msg = nothing
    try
        # msg = aigenerate(OpenAISchema(), conversation; #OllamaSchema(), conversation;
        #         variables=get_vars(options),
        #         operators=get_ops(options),
        #         N=N,
        #         gexpr1=gexpr[1],
        #         gexpr2=gexpr[2],
        #         gexpr3=gexpr[3],
        #         gexpr4=gexpr[4],
        #         gexpr5=gexpr[5],
        #         bexpr1=bexpr[1],
        #         bexpr2=bexpr[2],
        #         bexpr3=bexpr[3],
        #         bexpr4=bexpr[4],
        #         bexpr5=bexpr[5],
        #         model="gpt-3.5-turbo-0125"
        #         )
        msg = aigenerate(
            CustomOpenAISchema(),
            conversation; #OllamaSchema(), conversation;
            variables=get_vars(options),
            operators=get_ops(options),
            N=N,
            api_key=options.llm_options.api_key,
            model=options.llm_options.model,
            api_kwargs=convertDict(options.llm_options.api_kwargs),
            http_kwargs=convertDict(options.llm_options.http_kwargs),
        )
    catch e
        llm_recorder(options.llm_options, "None", "ideas|failed")
        return nothing
    end

    llm_recorder(options.llm_options, string(msg.content), "llm_output|ideas")

    idea_options = parse_msg_content(msg.content)

    N = min(size(idea_options)[1], N)

    if N == 0
        llm_recorder(options.llm_options, "None", "ideas|failed")
        return nothing
    end

    a = rand(1:N)

    chosen_idea1 = String(strip(idea_options[a], [' ', '\n', '"', ',', '.', '[', ']']))

    llm_recorder(options.llm_options, chosen_idea1, "ideas")
    pushfirst!(idea_database, chosen_idea1)

    if N > 1
        b = rand(1:(N - 1))
        if a == b
            b += 1
        end
        chosen_idea2 = String(strip(idea_options[b], [' ', '\n', '"', ',', '.', '[', ']']))

        llm_recorder(options.llm_options, chosen_idea2, "ideas")

        pushfirst!(idea_database, chosen_idea2)
    end

    num_add = 2
    for _ in 1:num_add
        out = prompt_evol(idea_database, options)
        if !isnothing(out)
            pushfirst!(idea_database, out)
        end
    end
end

function llm_mutate_op(
    ex::AbstractExpression{T}, options::Options, dominating, idea_database
)::AbstractExpression{T} where {T<:DATA_TYPE}
    tree = get_contents(ex)
    ex = with_contents(ex, llm_mutate_op(tree, options, dominating, idea_database))
    return ex
end

"""LLM Mutation on a tree"""
function llm_mutate_op(
    tree::AbstractExpressionNode{T}, options::Options, dominating, idea_database
)::AbstractExpressionNode{T} where {T<:DATA_TYPE}
    expr = tree_to_expr(tree, options) # TODO: change global expr right now, could do it by subtree (weighted near root more)
    N = 5
    # LLM prompt
    # TODO: we can use async map to do concurrent requests (useful for trying multiple prompts), see: https://github.com/svilupp/PromptingTools.jl?tab=readme-ov-file#asynchronous-execution

    # conversation = [
    #     SystemMessage(load_prompt(options.llm_options.prompts_dir * "mutate_system.txt")),
    #     UserMessage(load_prompt(options.llm_options.prompts_dir * "mutate_user.txt"))]

    assumptions = sample_context(
        idea_database,
        options.llm_options.num_pareto_context,
        options.llm_options.idea_threshold,
    )
    pareto = format_pareto(dominating, options, options.llm_options.num_pareto_context)
    if !options.llm_options.prompt_concepts
        assumptions = []
        pareto = []
    end
    conversation = [
        UserMessage(
            load_prompt(options.llm_options.prompts_dir * "mutate_system.txt") *
            "\n" *
            construct_prompt(
                load_prompt(options.llm_options.prompts_dir * "mutate_user.txt"),
                assumptions,
                "assump",
            ),
        ),
    ]
    llm_recorder(options.llm_options, conversation[1].content, "llm_input|mutate")

    if options.llm_options.llm_context != ""
        pushfirst!(assumptions, options.llm_options.llm_context)
    end

    msg = nothing
    try
        msg = aigenerate(
            CustomOpenAISchema(),
            conversation; #OllamaSchema(), conversation;
            variables=get_vars(options),
            operators=get_ops(options),
            N=N,
            expr=expr,
            api_key=options.llm_options.api_key,
            model=options.llm_options.model,
            api_kwargs=convertDict(options.llm_options.api_kwargs),
            http_kwargs=convertDict(options.llm_options.http_kwargs),
        )
    catch e
        llm_recorder(options.llm_options, "None", "mutate|failed")
        return tree
    end

    llm_recorder(options.llm_options, string(msg.content), "llm_output|mutate")

    mut_tree_options = parse_msg_content(msg.content)

    N = min(size(mut_tree_options)[1], N)

    if N == 0
        llm_recorder(options.llm_options, "None", "mutate|failed")
        return tree
    end

    for i in 1:N
        l = rand(1:N)
        t = expr_to_tree(
            T,
            String(strip(mut_tree_options[l], [' ', '\n', '"', ',', '.', '[', ']'])),
            options,
        )
        if t.val == 1 && t.constant
            continue
        end

        llm_recorder(options.llm_options, tree_to_expr(t, options), "mutate")

        return t
    end

    out = expr_to_tree(
        T, String(strip(mut_tree_options[1], [' ', '\n', '"', ',', '.', '[', ']'])), options
    )

    llm_recorder(options.llm_options, tree_to_expr(out, options), "mutate")

    return out
end

function llm_crossover_trees(
    ex1::E, ex2::E, options::Options, dominating, idea_database
)::Tuple{E,E} where {T,E<:AbstractExpression{T}}
    tree1 = get_contents(ex1)
    tree2 = get_contents(ex2)
    tree1, tree2 = llm_crossover_trees(tree1, tree2, options, dominating, idea_database)
    ex1 = with_contents(ex1, tree1)
    ex2 = with_contents(ex2, tree2)
    return ex1, ex2
end

"""LLM Crossover between two expressions"""
function llm_crossover_trees(
    tree1::AbstractExpressionNode{T},
    tree2::AbstractExpressionNode{T},
    options::Options,
    dominating,
    idea_database,
)::Tuple{AbstractExpressionNode{T},AbstractExpressionNode{T}} where {T<:DATA_TYPE}
    expr1 = tree_to_expr(tree1, options)
    expr2 = tree_to_expr(tree2, options)
    N = 5

    # LLM prompt
    # conversation = [
    #     SystemMessage(load_prompt(options.llm_options.prompts_dir * "crossover_system.txt")),
    #     UserMessage(load_prompt(options.llm_options.prompts_dir * "crossover_user.txt"))]
    assumptions = sample_context(
        idea_database,
        options.llm_options.num_pareto_context,
        options.llm_options.idea_threshold,
    )
    pareto = format_pareto(dominating, options, options.llm_options.num_pareto_context)
    if !options.llm_options.prompt_concepts
        assumptions = []
        pareto = []
    end

    conversation = [
        UserMessage(
            load_prompt(options.llm_options.prompts_dir * "crossover_system.txt") *
            "\n" *
            construct_prompt(
                load_prompt(options.llm_options.prompts_dir * "crossover_user.txt"),
                assumptions,
                "assump",
            ),
        ),
    ]

    if options.llm_options.llm_context != ""
        pushfirst!(assumptions, options.llm_options.llm_context)
    end

    llm_recorder(options.llm_options, conversation[1].content, "llm_input|crossover")

    msg = nothing
    try
        msg = aigenerate(
            CustomOpenAISchema(),
            conversation; #OllamaSchema(), conversation;
            variables=get_vars(options),
            operators=get_ops(options),
            N=N,
            # pareto1=pareto[1],
            # pareto2=pareto[2],
            # pareto3=pareto[3],
            expr1=expr1,
            expr2=expr2,
            api_key=options.llm_options.api_key,
            model=options.llm_options.model,
            api_kwargs=convertDict(options.llm_options.api_kwargs),
            http_kwargs=convertDict(options.llm_options.http_kwargs),
        )
    catch e
        llm_recorder(options.llm_options, "None", "crossover|failed")
        return tree1, tree2
    end

    llm_recorder(options.llm_options, string(msg.content), "llm_output|crossover")

    cross_tree_options = parse_msg_content(msg.content)

    cross_tree1 = nothing
    cross_tree2 = nothing

    N = min(size(cross_tree_options)[1], N)

    if N == 0
        llm_recorder(options.llm_options, "None", "crossover|failed")
        return tree1, tree2
    end

    if N == 1
        t = expr_to_tree(
            T,
            String(strip(cross_tree_options[1], [' ', '\n', '"', ',', '.', '[', ']'])),
            options,
        )
        
        llm_recorder(options.llm_options, tree_to_expr(t, options), "crossover")

        return t, tree2
    end

    for i in 1:(2 * N)
        l = rand(1:N)
        t = expr_to_tree(
            T,
            String(strip(cross_tree_options[l], [' ', '\n', '"', ',', '.', '[', ']'])),
            options,
        )
        if t.val == 1 && t.constant
            continue
        end

        if isnothing(cross_tree1)
            cross_tree1 = t
        elseif isnothing(cross_tree2)
            cross_tree2 = t
            break
        end
    end

    if isnothing(cross_tree1)
        cross_tree1 = expr_to_tree(
            T,
            String(strip(cross_tree_options[1], [' ', '\n', '"', ',', '.', '[', ']'])),
            options,
        )
    end

    if isnothing(cross_tree2)
        cross_tree2 = expr_to_tree(
            T,
            String(strip(cross_tree_options[2], [' ', '\n', '"', ',', '.', '[', ']'])),
            options,
        )
    end

    recording_str = tree_to_expr(cross_tree1, options) * " && " * tree_to_expr(cross_tree2, options)
    llm_recorder(options.llm_options, recording_str, "crossover")

    return cross_tree1, cross_tree2
end

end