on initialisation:

   0. clear any previously plotted trend lines

   1. get the current trend

   2. if trend is up:

      2A. get the currency's closest upper trend line

   2. else if trend is down:

      2B. get the currency's closest lower trend line

   3. get bank balance for portfolio risk

on start:

   0. every tick

      0A. check if active, if so, check trailing stop

   1. every bar

      1A. if trend is up, get significant upper trend line

      1B. if trend is down, get significant lower trend line

   2. every day

      2A. get trend

on deinitialise:

   1. send email alert - get last error code