util      = require 'util'
h         = require './helpers'
num       = require 'numbers'   #http://numbers.github.io
math      = require 'mathjs'    #http://mathjs.org/docs/reference/functions.html
Financejs = require 'financejs' #http://financejs.org/

precision = 18 # Adjust if required

module.exports.Finance = class Finance

  @name = "Finance"

  constructor: () ->
    @fin = new Financejs()

  # stupid javascript number rounding
  safeNumber: (num) ->
    x = num.toPrecision precision
    if x.indexOf "e" isnt -1 then Number(x.split("e")[0]) else num



  sum:      (array) -> @safeNumber(num.basic.sum     array)
  subtract: (array) -> @safeNumber(num.basic.subtraction array)
  square:   (array) -> @safeNumber(num.basic.square  array)

  product:  (array) -> @safeNumber(num.basic.product array)
  multiply: (x, y)  -> @safeNumber(@product   [x, y])
  divide:   (x, y)  -> @safeNumber(math.divide x, y)
  mod:      (x, y)  -> @safeNumber(math.mod    x, y)
  ceil:     (x)     -> @safeNumber(math.ceil   x)
  floor:    (x)     -> @safeNumber(math.floor  x)

  max:      (array) -> @safeNumber(num.basic.max array)
  min:      (array) -> @safeNumber(num.basic.min array)
  range:    (start, stop, step) -> num.basic.range start, stop, step

  pow:      (x, y)  -> @safeNumber(math.pow x, y)  # Javascript Math can be inaccurate..

  e:        (x)     -> @safeNumber(Math.exp x)

  nthRoot: (number, root) -> @safeNumber(math.nthRoot number, root)

  mean:     (array) -> num.statistic.mean   array
  median:   (array) -> num.statistic.median array
  mode:     (array) -> num.statistic.mode   array

  stringMode: (arr) ->
    object = {}
    for element in arr
      object[element] = if object[element] is undefined then 1 else object[element] + 1

    newArr = []
    newArr.push value for key, value of object

    max = @max newArr

    mode = ""
    for key, value of object
      if value is max then mode = key
    mode

  sd:          (array)          -> num.statistic.standardDev array
  correlation: (array1, array2) -> num.statistic.correlation array1, array2
  covariance:  (array1, array2) -> num.statistic.covariance  array1, array2

  exponentialRegression:     (array) -> num.statistic.exponentialRegression array
  linearRegression: (array1, array2) -> num.statistic.linearRegression      array1, array2

  quantile: (array, k, q) -> num.statistic.quantile(arr, k, q)

  # Future value
  fvSimple: (pv, r)      -> @product [pv, @sum([1, r])]
  fvCompound: (pv, r, n) -> @product [pv, @pow(@sum([1, r]), n)]
  fvCompoundFequency: (pv, r, m, n) -> @product [pv, @pow(@sum([1, @divide(r,m)]),  @product([m,n]))]
  fvCompoundContinuous: (pv, r, n)  -> @product [pv, @pow(@e(1), @product([r,n]))]

  # Interest Rates
  ear: (r, m)      -> @subtract [@pow(@sum([1, r]), m), 1]
  earCompound: (r) -> @subtract [@pow(@e(1), r), 1]
  interestRate: (FV, PV) -> @subtract [@divide(FV,PV), 1]

  # Future value cash flows
  fvAnnuity: (A, r, N)         -> @product [A, @divide(@ear(r, N), r)]
  pvFutureCashFlow: (FV, r, N) -> @product [FV, @pow(@sum([1, r]), -N)]
  pvFutureCashFlowCompounding: (FV, r, m, N) -> @product [FV, @pow(@sum([1, (r / m)]), -@product([m, N]))]
  pvCashFlowSeries: (A, r, N)  -> @product [ A, @divide((@subtract([ 1, (1 / @pow(@sum([1 + r]), N)) ])), r) ]
  pvCashFlowPerpetuity: (A, r) -> @divide(A, r)

  growthRate: (FV, PV, N) -> @subtract [@nthRoot(@divide(FV, PV), N), 1]

  pvAnnualCompoundToReachFV: (FV, PV, r) -> @divide math.log(@divide(FV, PV)), math.log(@sum([1, r]))

  pvCashFlowSeries2: (A, r, N)  ->
    # @product [ A, @divide((@subtract([ 1, (1 / @pow(@sum([1 + r]), N)) ])), r) ]

    #@product [A, @divide(@subtract([1, @divide(1, @pow(@sum([1, r]), N))]), r)]

    console.log "A: #{A}"
    console.log "r: #{r}"
    console.log "N: #{N}"
    @product [A, @divide(@subtract([1, @divide(1, @pow(@sum([1, r]), N))]), r)]

  loanRepaymentsPeriodicCompoundInterest: (PV, r, m, N) ->
    annualRate = @divide(r,m)
    periods    = @product([m,N])
    PV / @divide((@pvCashFlowSeries PV, annualRate, periods), PV)

  # Net present value
  npv: (CF, r) ->
    sum = 0
    for t in [0..(CF.length - 1)]
      switch t == 0
        when true  then sum  = @sum [sum, CF[t]]
        when false then sum += @divide(CF[t], @pow(@sum([1, r]), t))
    sum

  npvPerpetuity: (CF, r) -> @sum [CF[0], @divide(CF[1],r)]

  irr:(CF, I) -> @divide(CF, I)

  irr2: (CF) ->
    # console.log(CF)
    # @fin.IRR(-500000, 200000, 300000, 200000)
    guess = 0.001
    while true
      npv   = @npv CF, guess
      break unless npv > 0.000001

      guess = @sum [guess, 0.001]
    guess * 100

  # Perfolio Returns Measurements
  hpr: (P0, P1, D1) -> @divide @sum([@subtract([P1, P0]), D1]), P0

  # Money Market Returns
  mmAnnualYield:(D, F, t)            -> @product [@divide(D, F), @divide(360, t)]
  mmAnnualDollarDiscount:(rBD, F, t) -> @product [@product([rBD, F]), @divide(t, 360)]
  mmAnnualPurchasePrice:(F, D)       -> @subtract [F, D]
  mmHoldingPeriodYield: (P0, P1, D1) -> @hpr P0, P1, D1
  mmEffectiveAnnualYield: (HPY, t)   -> @subtract [@pow(@sum([1, HPY]), @divide(365, t)), 1]
  mmYield: (rBD, F, P0)              -> @product [rBD, @divide(F, P0)]

  # Statistics

  frequencyDistribution:(step, array) ->
    # console.log "array.length: #{array.length}"
    # string = ""
    # string += "#{element} " for element in array.sort (a,b) -> a - b
    # console.log string

    min    = (@min array) - 1
    min    = Math.sign(min) * Math.round(Math.abs(min))
    max    = @max array
    range  = max - min

    groups = @divide range, step
    mod    = @mod array.length, step
    if mod > 0 then groups = @floor(groups) + 1
    groups = @ceil groups

    freqArray = []
    cummulativeFrequency = 0

    for i in [0..(@subtract [groups, 1])]
      start = min   + @product [i, step]
      end   = start + step

      matches = []
      for element in array
        matches.push element if element >= start and element < end

      count                 = matches.length
      cummulativeFrequency += count

      object =
        start:     start
        end:       end
        matches:   matches
        frequency: count
        relativeFrequency: parseFloat((@divide count, array.length).toFixed(4)) * 100
        cummulativeFrequency: cummulativeFrequency
        cummulativeRelativeFrequency: parseFloat((@divide cummulativeFrequency, array.length).toFixed(4)) * 100

      # console.log "#{i}: start: #{object.start} end: #{object.end} matches: #{object.matches}, frequency: #{object.frequency} relativeFrequency: #{object.relativeFrequency} cummulativeFrequency: #{object.cummulativeFrequency} cummulativeRelativeFrequency: #{object.cummulativeRelativeFrequency}"
      freqArray.push object
    freqArray

  frequencyDistributionHistorgram:(freqArray, key) ->

    array = []
    for element in freqArray
      object =
        x: "#{element.start} - #{element.end}"
        y: element[key]
      array.push object
    array


  weightedReturns: (object) ->
    result = 0
    for key, value of object
      result += @product [value.weight, value.return]
    result
