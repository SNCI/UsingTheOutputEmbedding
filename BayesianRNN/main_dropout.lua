-- Bayesian dropout by extending main_naive_dropout. Setting dropout_h = 0 should recover 
-- (approx) the other file.  We use the same noise mask throughout the seq, but different masks 
-- for different gates.  We init sequences with 0 rather than prev state. 

-- ToDo: 
-- V * fix fp_MC (underflow issues)
-- V * implement embedding dropout
-- V * optimise code (lstm unit is 2-3 times slower now)
-- * text fp_MC fix
-- * run_test_all with MC_dropout=true takes ages

local ok,cunn = pcall(require, 'fbcunn')
if not ok then
    ok,cunn = pcall(require,'cunn')
    if ok then
        print("warning: fbcunn not found. Falling back to cunn") 
        LookupTable = nn.LookupTable
    else
        print("Could not find cunn or fbcunn. Either is required")
        os.exit()
    end
else
    deviceParams = cutorch.getDeviceProperties(1)
    cudaComputeCapability = deviceParams.major + deviceParams.minor/10
    LookupTable = nn.LookupTable
end
require('nngraph')
require('base')
local ptb = require('data')


-- -- param 7:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200,
--                 dropout_i=0.5,
--                 dropout_h=0.5,
--                 dropout_o=0.5,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10}

-- -- debug param 7:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 -- rnn_size=100, -- small enough to run on GPU 2
--                 rnn_size=200, -- small enough to run on GPU 2
--                 dropout_x=0,
--                 dropout_i=0.5,
--                 dropout_h=0,
--                 dropout_o=0.5,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10} -- lots more iterations

-- -- param 12:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0,
--                 dropout_i=0.5,
--                 dropout_h=0,
--                 dropout_o=0.5,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10} -- lots more iterations

-- -- param 13:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0.1,
--                 dropout_i=0.5,
--                 dropout_h=0.1,
--                 dropout_o=0.5,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10} -- lots more iterations

-- -- param 14:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0.25,
--                 dropout_i=0.25,
--                 dropout_h=0.25,
--                 dropout_o=0.25,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10}

-- -- param 15:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0.4,
--                 dropout_i=0.4,
--                 dropout_h=0.4,
--                 dropout_o=0.4,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10}

-- -- param 16:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0.2,
--                 dropout_i=0.5,
--                 dropout_h=0.2,
--                 dropout_o=0.5,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10}

-- -- param 17:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0.25,
--                 dropout_i=0.25,
--                 dropout_h=0.25,
--                 dropout_o=0.25,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10,
--                 weight_decay=1e-6}

-- -- param 18:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0.25,
--                 dropout_i=0.25,
--                 dropout_h=0.25,
--                 dropout_o=0.25,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10,
--                 weight_decay=1e-4}

-- param 19:
local params = {batch_size=20,
                seq_length=20,
                layers=2,
                decay=1.,
                rnn_size=200, 
                dropout_x=0.25,
                dropout_i=0.25,
                dropout_h=0.25,
                dropout_o=0.25,
                init_weight=0.1,
                lr=1,
                vocab_size=10000,
                max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
                max_max_epoch=180,
                max_grad_norm=5,
                MC_dropout=false,
                T=10,
                weight_decay=1e-5}

-- -- param 20:
-- local params = {batch_size=20,
--                 seq_length=20,
--                 layers=2,
--                 decay=1.,
--                 rnn_size=200, 
--                 dropout_x=0.5,
--                 dropout_i=0.5,
--                 dropout_h=0.5,
--                 dropout_o=0.5,
--                 init_weight=0.1,
--                 lr=1,
--                 vocab_size=10000,
--                 max_epoch=180, -- start decreasing learning rate, keeping lr > 0.004
--                 max_max_epoch=180,
--                 max_grad_norm=5,
--                 MC_dropout=false,
--                 T=10,
--                 weight_decay=1e-5}

-- Author: use dropout from within the script rather than nn's
local disable_dropout = false
local function local_Dropout(input, noise)
  return nn.CMulTable()({input, noise})
end

local function transfer_data(x)
  return x:cuda()
end

local state_train, state_valid, state_test
local model = {}
local paramx, paramdx

local function lstm(x, prev_c, prev_h, noise_i, noise_h)
  -- Reshape to (batch_size, n_gates, hid_size)
  -- Then slice the n_gates dimension, i.e dimension 2
  local reshaped_noise_i = nn.Reshape(4,params.rnn_size)(noise_i)
  local reshaped_noise_h = nn.Reshape(4,params.rnn_size)(noise_h)
  local sliced_noise_i   = nn.SplitTable(2)(reshaped_noise_i)
  local sliced_noise_h   = nn.SplitTable(2)(reshaped_noise_h)
  -- Calculate all four gates 
  local i2h, h2h         = {}, {}
  for i = 1, 4 do 
    -- Use select table to fetch each gate
    local dropped_x      = local_Dropout(x, nn.SelectTable(i)(sliced_noise_i))
    local dropped_h      = local_Dropout(prev_h, nn.SelectTable(i)(sliced_noise_h))
    i2h[i]               = nn.Linear(params.rnn_size, params.rnn_size)(dropped_x)
    h2h[i]               = nn.Linear(params.rnn_size, params.rnn_size)(dropped_h)
  end
  
  -- Apply nonlinearity
  local in_gate          = nn.Sigmoid()(nn.CAddTable()({i2h[1], h2h[1]}))
  local in_transform     = nn.Tanh()(nn.CAddTable()({i2h[2], h2h[2]}))
  local forget_gate      = nn.Sigmoid()(nn.CAddTable()({i2h[3], h2h[3]}))
  local out_gate         = nn.Sigmoid()(nn.CAddTable()({i2h[4], h2h[4]}))

  local next_c           = nn.CAddTable()({
      nn.CMulTable()({forget_gate, prev_c}),
      nn.CMulTable()({in_gate,     in_transform})
  })
  local next_h           = nn.CMulTable()({out_gate, nn.Tanh()(next_c)})

  return next_c, next_h
end

-- local function lstm(x, prev_c, prev_h, noise_i, noise_h)
--   -- Author: tie noise mask for all gates to keep efficiency (65% quicker, but worse results)
--   local dropped_x = local_Dropout(x, noise_i)
--   local dropped_h = local_Dropout(prev_h, noise_h)
--   -- Calculate all four gates in one go
--   local i2h = nn.Linear(params.rnn_size, 4*params.rnn_size)(dropped_x)
--   local h2h = nn.Linear(params.rnn_size, 4*params.rnn_size)(dropped_h)
--   local gates = nn.CAddTable()({i2h, h2h})
  
--   -- Reshape to (batch_size, n_gates, hid_size)
--   -- Then slice the n_gates dimension, i.e dimension 2
--   local reshaped_gates =  nn.Reshape(4,params.rnn_size)(gates)
--   local sliced_gates = nn.SplitTable(2)(reshaped_gates)
  
--   -- Use select gate to fetch each gate and apply nonlinearity
--   local in_gate          = nn.Sigmoid()(nn.SelectTable(1)(sliced_gates))
--   local in_transform     = nn.Tanh()(nn.SelectTable(2)(sliced_gates))
--   local forget_gate      = nn.Sigmoid()(nn.SelectTable(3)(sliced_gates))
--   local out_gate         = nn.Sigmoid()(nn.SelectTable(4)(sliced_gates))

--   local next_c           = nn.CAddTable()({
--       nn.CMulTable()({forget_gate, prev_c}),
--       nn.CMulTable()({in_gate,     in_transform})
--   })
--   local next_h           = nn.CMulTable()({out_gate, nn.Tanh()(next_c)})

--   return next_c, next_h
-- end

local function create_network()
  local x                = nn.Identity()()
  local y                = nn.Identity()()
  local prev_s           = nn.Identity()()
  local noise_x          = nn.Identity()()
  local noise_i          = nn.Identity()()
  local noise_h          = nn.Identity()()
  local noise_o          = nn.Identity()()
  local i                = {[0] = LookupTable(params.vocab_size,
                                              params.rnn_size)(x)}
  i[0] = local_Dropout(i[0], noise_x)
  local next_s           = {}
  local split            = {prev_s:split(2 * params.layers)}
  local noise_i_split    = {noise_i:split(params.layers)}
  local noise_h_split    = {noise_h:split(params.layers)}
  for layer_idx = 1, params.layers do
    local prev_c         = split[2 * layer_idx - 1]
    local prev_h         = split[2 * layer_idx]
    local n_i            = noise_i_split[layer_idx]
    local n_h            = noise_h_split[layer_idx]
    local next_c, next_h = lstm(i[layer_idx - 1], prev_c, prev_h, n_i, n_h)
    table.insert(next_s, next_c)
    table.insert(next_s, next_h)
    i[layer_idx] = next_h
  end
  local h2y              = nn.Linear(params.rnn_size, params.vocab_size)
  local dropped          = local_Dropout(i[params.layers], noise_o)
  local pred             = nn.LogSoftMax()(h2y(dropped))
  local err              = nn.ClassNLLCriterion()({pred, y})
  local module           = nn.gModule({x, y, prev_s, noise_x, noise_i, noise_h, noise_o},
                                      {err, nn.Identity()(next_s)})
  module:getParameters():uniform(-params.init_weight, params.init_weight)
  return transfer_data(module)
end

local function setup()
  print("Creating a RNN LSTM network.")
  local core_network = create_network()
  paramx, paramdx = core_network:getParameters()
  model.s = {}
  model.ds = {}
  model.start_s = {}
  for j = 0, params.seq_length do
    model.s[j] = {}
    for d = 1, 2 * params.layers do
      model.s[j][d] = transfer_data(torch.zeros(params.batch_size, params.rnn_size))
    end
  end
  for d = 1, 2 * params.layers do
    model.start_s[d] = transfer_data(torch.zeros(params.batch_size, params.rnn_size))
    model.ds[d] = transfer_data(torch.zeros(params.batch_size, params.rnn_size))
  end
  -- Author: Note that the data comes in batches. We need noise to have batch by layers 
  -- by rnn_size dimensionality.
  model.noise_i = {}
  model.noise_x = {}
  model.noise_xe = {} -- Author: we expand the dims of noise_x to match data dim
  for j = 1, params.seq_length do
    model.noise_x[j] = transfer_data(torch.zeros(params.batch_size, 1))
    model.noise_xe[j] = torch.expand(model.noise_x[j], params.batch_size, params.rnn_size)
    model.noise_xe[j] = transfer_data(model.noise_xe[j])
  end
  model.noise_h = {}
  for d = 1, params.layers do
    model.noise_i[d] = transfer_data(torch.zeros(params.batch_size, 4 * params.rnn_size))
    model.noise_h[d] = transfer_data(torch.zeros(params.batch_size, 4 * params.rnn_size))
    -- Author: tie noise mask for all gates (for efficiency - 65% quicker, but worse results)
    -- model.noise_i[d] = transfer_data(torch.zeros(params.batch_size, params.rnn_size))
    -- model.noise_h[d] = transfer_data(torch.zeros(params.batch_size, params.rnn_size))
  end
  model.noise_o = transfer_data(torch.zeros(params.batch_size, params.rnn_size))
  model.core_network = core_network
  model.rnns = g_cloneManyTimes(core_network, params.seq_length)
  model.norm_dw = 0
  model.err = transfer_data(torch.zeros(params.seq_length))
  -- Author: For MC dropout we want to get pred as model output rather than the negative log probs (?)
  model.pred = {}
  for j = 1, params.seq_length do
    model.pred[j] = transfer_data(torch.zeros(params.batch_size, params.vocab_size))
  end
  local y                = nn.Identity()()
  local pred             = nn.Identity()()
  local err              = nn.ClassNLLCriterion()({pred, y})
  model.test             = transfer_data(nn.gModule({y, pred}, {err}))
end

local function reset_state(state)
  state.pos = 1
  if model ~= nil and model.start_s ~= nil then
    for d = 1, 2 * params.layers do
      model.start_s[d]:zero()
    end
  end
end

local function reset_ds()
  for d = 1, #model.ds do
    model.ds[d]:zero()
  end
end

-- Author: convenience functions to handle noise
local function sample_noise(state)
  -- Author: assuming state.pos is at start of input sequence
  for i = 1, params.seq_length do
    -- Author: cheating here - sampling iid Berns for each x; should tie over words
    model.noise_x[i]:bernoulli(1 - params.dropout_x)
    model.noise_x[i]:div(1 - params.dropout_x)
  end
  -- Author: tying over words - overriding Berns for words that were already sampled. 
  -- this is efficient for short sequences, but longer ones it might be better to sample 
  -- once for all words.
  for b = 1, params.batch_size do
    for i = 1, params.seq_length do
      local x = state.data[state.pos + i - 1]
      for j = i+1, params.seq_length do
        if state.data[state.pos + j - 1] == x then
          model.noise_x[j][b] = model.noise_x[i][b]
          -- we only need to override the first time; afterwards subsequent are copied:
          break
        end
      end
    end
  end
  for d = 1, params.layers do
    model.noise_i[d]:bernoulli(1 - params.dropout_i)
    model.noise_i[d]:div(1 - params.dropout_i)
    model.noise_h[d]:bernoulli(1 - params.dropout_h)
    model.noise_h[d]:div(1 - params.dropout_h)
  end
  model.noise_o:bernoulli(1 - params.dropout_o)
  model.noise_o:div(1 - params.dropout_o)
end

local function reset_noise()
  for j = 1, params.seq_length do
    model.noise_x[j]:zero():add(1)
  end
  for d = 1, params.layers do
    model.noise_i[d]:zero():add(1)
    model.noise_h[d]:zero():add(1)
  end
  model.noise_o:zero():add(1)
end

local function fp(state)
  g_replace_table(model.s[0], model.start_s)
  if state.pos + params.seq_length > state.data:size(1) then
    reset_state(state)
  end
  -- Author: should reset noise out of function 
  if disable_dropout then reset_noise() else sample_noise(state) end
  for i = 1, params.seq_length do
    local x = state.data[state.pos]
    local y = state.data[state.pos + 1]
    local s = model.s[i - 1]
    model.err[i], model.s[i] = unpack(model.rnns[i]:forward(
      {x, y, s, model.noise_xe[i], model.noise_i, model.noise_h, model.noise_o}))
    state.pos = state.pos + 1
  end
  -- Author: we do not keep the last state to init the next sequence, but keep it at zero
  -- g_replace_table(model.start_s, model.s[params.seq_length])
  return model.err
end

local function fp_MC(state)
  g_replace_table(model.s[0], model.start_s)
  if state.pos + params.seq_length > state.data:size(1) then
    reset_state(state)
  end
  -- Author: reset pred
  for i = 1, params.seq_length do
    model.pred[i]:zero()
  end
  local T = single_stochastic_dropout_pass and 1 or params.T
  for t = 1, T do
    sample_noise(state)
    for i = 1, params.seq_length do
      local x = state.data[state.pos + i - 1]
      local y = state.data[state.pos + i]
      local s = model.s[i - 1]
      -- Author: we sample several times and average
      model.s[i] = model.rnns[i]:forward({x, y, s, 
        model.noise_xe[i], model.noise_i, model.noise_h, model.noise_o})[2]
      local pred = model.rnns[i].outnode.data.mapindex[1].input[1]
      model.pred[i]:add(pred:exp()) -- does this underflow?
    end
  end
  for i = 1, params.seq_length do
    local y = state.data[state.pos + i]
    model.pred[i]:log():add(-torch.log(T))
    model.err[i] = model.test:forward({y, model.pred[i]})
  end
  state.pos = state.pos + params.seq_length
  -- Author: we do not keep the last state to init the next sequence, but keep it at zero
  -- g_replace_table(model.start_s, model.s[params.seq_length])
  return model.err
end

local function bp(state)
  -- Author: we truncate the derivative at seq_length, which is equivalent
  -- to using sequences of length seq_length but with smarter initialisation
  -- than putting zeros for the first state. This is easier than bucketing,
  -- but carries internal states over <eos> which is bad. Especially because
  -- that means we use shorter sequences for each sentence. Note that it seems
  -- bad to reset ds if we use the prev s?
  paramdx:zero()
  reset_ds()
  for i = params.seq_length, 1, -1 do
    state.pos = state.pos - 1
    local x = state.data[state.pos]
    local y = state.data[state.pos + 1]
    local s = model.s[i - 1]
    local derr = transfer_data(torch.ones(1))
    local tmp = model.rnns[i]:backward( -- Author: do we need model.noise_x[i+1]?
      {x, y, s, model.noise_xe[i], model.noise_i, model.noise_h, model.noise_o},
      {derr, model.ds})[3]
    g_replace_table(model.ds, tmp)
    cutorch.synchronize()
  end
  state.pos = state.pos + params.seq_length
  model.norm_dw = paramdx:norm()
  if model.norm_dw > params.max_grad_norm then
    local shrink_factor = params.max_grad_norm / model.norm_dw
    paramdx:mul(shrink_factor)
  end
  paramx:add(paramdx:mul(-params.lr))
  -- Author: add weight decay
  paramx:add(-params.weight_decay, paramx)
end

local function run_valid()
  reset_state(state_valid)
  -- Author: disable dropout for standard dropout
  if not params.MC_dropout then
    disable_dropout = true
  end
  local len = (state_valid.data:size(1) - 1) / (params.seq_length)
  local perp = 0
  for i = 1, len do
    local p = params.MC_dropout and fp_MC(state_valid) or fp(state_valid)
    perp = perp + p:mean()
  end
  print("Validation set perplexity : " .. g_f3(torch.exp(perp / len)))
  if not params.MC_dropout then
    disable_dropout = false
  end
end

local function run_test()
  -- follows the same code of validation, using average perp of non-overlapping sequences
  reset_state(state_test)
  -- Author: disable dropout for standard dropout
  if not params.MC_dropout then
    disable_dropout = true
  end
  local len = (state_test.data:size(1) - 1) / (params.seq_length)
  local perp = 0
  for i = 1, len do
    local p = params.MC_dropout and fp_MC(state_test) or fp(state_test)
    perp = perp + p:mean()
  end
  print("Test set perplexity : " .. g_f3(torch.exp(perp / len)))
  if not params.MC_dropout then
    disable_dropout = false
  end
end

local function run_test_all()
  -- follows the same code of validation, but with overlapping sequences using last seq perp
  -- Author: need to test this function!
  reset_state(state_test)
  -- Author: disable test time dropout for standard dropout approx
  if not params.MC_dropout then
    disable_dropout = true
  end
  local len = state_test.data:size(1) - params.seq_length
  local perp = 0
  for i = 1, len do
    state_test.pos = i
    local p = params.MC_dropout and fp_MC(state_test) or fp(state_test)
    perp = perp + p[params.seq_length] -- use perp of last seq element p(s_l | s_1 .. s_lm1)
  end
  print("Test set perplexity : " .. g_f3(torch.exp(perp / len)))
  if not params.MC_dropout then
    disable_dropout = false
  end
end

local function run_test_orig()
  reset_state(state_test)
  if params.MC_dropout then
    sample_noise()
  else
    reset_noise()
  end
  local perp = 0
  local len = state_test.data:size(1)
  g_replace_table(model.s[0], model.start_s)
  for i = 1, (len - 1) do
    local x = state_test.data[i]
    local y = state_test.data[i + 1]
    perp_tmp, model.s[1] = unpack(model.rnns[1]:forward(
      {x, y, model.s[0], model.noise_i, model.noise_h, model.noise_o}))
    perp = perp + perp_tmp[1]
    g_replace_table(model.s[0], model.s[1])
  end
  print("Test set perplexity : " .. g_f3(torch.exp(perp / (len - 1))))
end

local function main()
  g_init_gpu(arg)
  state_train = {data=transfer_data(ptb.traindataset(params.batch_size))}
  state_valid =  {data=transfer_data(ptb.validdataset(params.batch_size))}
  state_test =  {data=transfer_data(ptb.testdataset(params.batch_size))}
  print("Network parameters:")
  print(params)
  local states = {state_train, state_valid, state_test}
  for _, state in pairs(states) do
    reset_state(state)
  end
  setup()
  local step = 0
  local epoch = 0
  local total_cases = 0
  local beginning_time = torch.tic()
  local start_time = torch.tic()
  print("Starting training.")
  local epoch_size = torch.floor(state_train.data:size(1) / params.seq_length)
  local perps
  while epoch < params.max_max_epoch do
    local perp = fp(state_train):mean()
    if perps == nil then
      perps = torch.zeros(epoch_size):add(perp)
    end
    perps[step % epoch_size + 1] = perp
    step = step + 1
    bp(state_train)
    total_cases = total_cases + params.seq_length * params.batch_size
    epoch = step / epoch_size
    if step % torch.round(epoch_size / 10) == 10 then
      local wps = torch.floor(total_cases / torch.toc(start_time))
      local since_beginning = g_d(torch.toc(beginning_time) / 60)
      print('epoch = ' .. g_f3(epoch) ..
            ', train perp. = ' .. g_f3(torch.exp(perps:mean())) ..
            ', wps = ' .. wps ..
            ', dw:norm() = ' .. g_f3(model.norm_dw) ..
            ', lr = ' ..  g_f3(params.lr) ..
            ', since beginning = ' .. since_beginning .. ' mins.')
    end
    if step % epoch_size == 0 then
      params.MC_dropout = false
      run_valid()
      -- params.MC_dropout = true
      -- run_valid()
      if epoch > params.max_epoch then
          params.lr = params.lr / params.decay
      end
    end
    if step % 33 == 0 then
      cutorch.synchronize()
      collectgarbage()
    end
  end
  params.MC_dropout = false
  run_test()
  params.MC_dropout = true
  run_test()
  params.MC_dropout = false
  run_test_all()
  -- params.MC_dropout = true
  -- run_test_all()
  print("Training is over.")
end

main()
