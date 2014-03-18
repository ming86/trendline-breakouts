extern int EXT_SWINGS = 2; // swing level, 0 is lowest, 2 is most common
extern int EXT_NO_SWING_LMT = 12; // don't consider the latest X bars as swing points to draw trend lines 
extern int EXT_ATR = 300; // ATR(x)
extern double EXT_ATR_MAX_SLOPE = 0.05; // multiple of ATR that would be considered maximum slope 
extern double EXT_ATR_BUFFER = 0.05; // multiple of ATR to add to low/high for it to be considered a "touch"
extern int EXT_NULL_CLOSES = 0; // number of closes beyond trend line to nullify it as a valid trend line
extern int EXT_NUM_TOUCHES = 3; // (inclusive) number of touches needed to be considered a valid trend line
extern int EXT_RES_COLOR = IndianRed; // horizontal resistance line http://docs.mql4.com/constants/colors
extern int EXT_SUP_COLOR = PaleGreen; // horizontal support line http://docs.mql4.com/constants/colors
extern int EXT_SLOPE_RES_COLOR = LightSalmon; // sloping resistance line http://docs.mql4.com/constants/colors
extern int EXT_SLOPE_SUP_COLOR = Lime; // sloping support line http://docs.mql4.com/constants/colors


int start() {
   string sym = Symbol();
   int per = Period();
   int d = Digits;
   ObjectsDeleteAll( 0 );

   double tlUp = getTrendLine( sym, per, true );
   double tlDn = getTrendLine( sym, per, false );

   // let's comment the values of the trend line to see what their price is
   Comment( "tlUp=" + DoubleToStr( tlUp, d ) + "  tlDn=" + DoubleToStr( tlDn, d ) );

   return( 0 );
}

double getTrendLine( string sym, int per, bool isUp ) {
   int swingArray[], tempArray[];
   initBarsArray( sym, per, swingArray ); // initialise array with all bars

   // refine the array according to the swing level set
   for ( int s = 0; s <= EXT_SWINGS; s += 1 ) {
      int arrLen = ArraySize( swingArray );     
      for ( int a = 2; a < arrLen; a += 1 ) {
         if ( isUp ) {
            if ( isPeak( sym, swingArray[a-2], swingArray[a-1], swingArray[a], per ) ) intArrayPush( tempArray, swingArray[a-1] );
         } else {
            if ( isTrough( sym, swingArray[a-2], swingArray[a-1], swingArray[a], per ) ) intArrayPush( tempArray, swingArray[a-1] );
         }
      }
      // copy array
      flushArray( swingArray );
      ArrayCopy( swingArray, tempArray );
      flushArray( tempArray );
   }

   // now that we have an array of all valid swing points we test each combination
   // of points to determine whether they are trend lines that meet our specifications
   double result, tempResult;
   int arrSize = ArraySize( swingArray );
   for ( a = 0; a < arrSize; a += 1 ) {
      // first we will test the horizontal trend line value of this swing point
      tempResult = getLastValidPoint( sym, swingArray[a], swingArray[a], per, isUp );     

      // if we get a number other than zero from our valid point function we will plot this trend line
      if ( tempResult > 0 ) {
         // let's compare the last valid point of the horizontal trend line to see if
         // it is closer to price than our current result
         if ( result == 0 ) result = tempResult;
         if ( isUp && tempResult < result ) result = tempResult;
         if ( !isUp && tempResult > result ) result = tempResult;

         // draw trend line
         if ( isUp ) {
            ObjectCreate( "Res@" + swingArray[a],OBJ_TREND,0,Time[swingArray[a]],High[swingArray[a]],Time[0], tempResult );
            ObjectSet( "Res@" + swingArray[a], OBJPROP_STYLE, STYLE_SOLID );
            ObjectSet( "Res@" + swingArray[a], OBJPROP_COLOR, EXT_RES_COLOR ); 
         } else {
            ObjectCreate( "Sup@" + swingArray[a],OBJ_TREND,0,Time[swingArray[a]],Low[swingArray[a]],Time[0], tempResult );
            ObjectSet( "Sup@" + swingArray[a], OBJPROP_STYLE, STYLE_SOLID );
            ObjectSet( "Sup@" + swingArray[a], OBJPROP_COLOR, EXT_SUP_COLOR ); 
         }
      }

      // next we'll test sloping trend lines
      for ( int b = a + 1; b < arrSize; b += 1 ) {
         // get last valid point of sloping trend line
         tempResult = getLastValidPoint( sym, swingArray[a], swingArray[b], per, isUp );

         if ( tempResult > 0 ) {
            // let's compare the last valid point of the sloping trend line to see if
            // it is closer to price than our current result
            if ( result == 0 ) result = tempResult;
            if ( isUp && tempResult < result ) result = tempResult;
            if ( !isUp && tempResult > result ) result = tempResult;

            // draw trend line
            if ( isUp ) {
               ObjectCreate( "SlopeRes@" + swingArray[a],OBJ_TREND,0,Time[swingArray[a]],High[swingArray[a]],Time[0], tempResult );
               ObjectSet( "SlopeRes@" + swingArray[a], OBJPROP_STYLE, STYLE_SOLID );
               ObjectSet( "SlopeRes@" + swingArray[a], OBJPROP_COLOR, EXT_SLOPE_RES_COLOR ); 
            } else {
               ObjectCreate( "SlopeSup@" + swingArray[a],OBJ_TREND,0,Time[swingArray[a]],Low[swingArray[a]],Time[0], tempResult );
               ObjectSet( "SlopeSup@" + swingArray[a], OBJPROP_STYLE, STYLE_SOLID );
               ObjectSet( "SlopeSup@" + swingArray[a], OBJPROP_COLOR, EXT_SLOPE_SUP_COLOR ); 
            }
         }
      }
   }

   // return the value of the closest trend line's current value
   return ( result );
}

void intArrayPush( int& arr[], int elem ) {
   int size = ArraySize( arr );
   ArrayResize( arr, size + 1 );
   arr[ size ] = elem;
}

void initBarsArray( string sym, int per, int& arr[] ) {
   int b = iBars( sym, per );
   for ( int i = b - 1; i > EXT_NO_SWING_LMT; i -= 1 ) {
      intArrayPush( arr, i );
   }
}

void flushArray( int& arr[] ) {
   ArrayInitialize( arr, 0 );
   ArrayResize( arr, 0 );
}

bool isTrough( string sym, int left, int mid, int right, int per ) {
   if ( iLow( sym, per, left ) >= iLow( sym, per, mid ) && iLow( sym, per, mid ) < iLow( sym, per, right ) ) return ( true );
   return ( false ); 
}

bool isPeak( string sym, int left, int mid, int right, int per ) {
   if ( iHigh( sym, per, left ) <= iHigh( sym, per, mid ) && iHigh( sym, per, mid ) > iHigh( sym, per, right ) ) return ( true );
   return ( false );
}

double getLastValidPoint( string sym, int b1, int b2, int per, bool isUp ) {
   // first we'll obtain the slope of the trend line to check its gradient
   double slope = getSlope( sym, b1, b2, per, isUp ), pt, buffer;

   // we will use a multiple of the ATR to check whether a trend line is too sharp
   // if it is we will exit with a value of 0
   if ( MathAbs( slope ) > iATR( sym, per, EXT_ATR, 0 ) * EXT_ATR_MAX_SLOPE ) return ( 0 );

   // otherwise we will now test whether the trend line has had the right amount of
   // touches without exceeding the number of closes beyond it.
   int x = 0, t = 0, lastTouch;
   for ( int i = b1; i >= 0; i -= 1 ) {
      // adding a buffer in case price gets close to trend line but doesn't actually touch
      buffer = iATR( sym, per, EXT_ATR, i ) * EXT_ATR_BUFFER; 

      if ( isUp ) {
         pt = iHigh( sym, per, b1 ) + ( slope * ( b1 - i ) );
         if ( iClose( sym, per, i ) > pt && i > 0 ) x += 1;
         // a "touch" is made when it has formed a peak
         if ( i == lastTouch && isPeak( sym, i+2, i+1, i, per ) ) t += 1;
         if ( iHigh( sym, per, i ) + buffer >= pt ) lastTouch = i-1; 
      } else {
         pt = iLow( sym, per, b1 ) + ( slope * ( b1 - i ) );         
         if ( iClose( sym, per, i ) < pt && i > 0 ) x += 1;
         // a "touch" is made when it has formed a trough
         if ( i == lastTouch && isTrough( sym, i+2, i+1, i, per ) ) t += 1;
         if ( iLow( sym, per, i ) - buffer <= pt ) lastTouch = i-1;     
      }     

      // check if trend line has broken the number of closes to nullify it
      if ( x > EXT_NULL_CLOSES ) {
         // we want to plot our broken lines, however, we only want to plot
         // those broken trend lines which exceeded our number of touches and which
         // didn't get broken between their swing points
         if ( i < b2 && t >= EXT_NUM_TOUCHES ) {
            if ( isUp ) {
               ObjectCreate( "BrokenTL@" + b1,OBJ_TREND,0,Time[b1],High[b1],Time[i], pt );
               ObjectSet( "BrokenTL@" + b1, OBJPROP_RAY, false );
               ObjectSet( "BrokenTL@" + b1, OBJPROP_STYLE, STYLE_SOLID );
               ObjectSet( "BrokenTL@" + b1, OBJPROP_COLOR, EXT_SLOPE_RES_COLOR ); 
            } else {
               ObjectCreate( "BrokenTL@" + b1,OBJ_TREND,0,Time[b1],Low[b1],Time[i], pt );
               ObjectSet( "BrokenTL@" + b1, OBJPROP_RAY, false );
               ObjectSet( "BrokenTL@" + b1, OBJPROP_STYLE, STYLE_SOLID );
               ObjectSet( "BrokenTL@" + b1, OBJPROP_COLOR, EXT_SLOPE_SUP_COLOR ); 
            }
         }
         return ( 0 );
      }
   }

   // if trend line exceeds the number of touches return the current value of the trend line
   if ( t >= EXT_NUM_TOUCHES ) return ( pt );
   // otherwise return 0
   return ( 0 );
}

double getSlope( string sym, int b1, int b2, int per, bool isUp ) {
   if ( b1 == b2 ) return ( 0 );
   if ( isUp ) {
      return ( ( iHigh( sym, per, b1 ) - iHigh( sym, per, b2 ) ) / ( b2 - b1 ) ); // b2 - b1 is deliberate
   } else {
      return ( ( iLow( sym, per, b1 ) - iLow( sym, per, b2 ) ) / ( b2 - b1 ) ); // b2 - b1 is deliberate
   }
}