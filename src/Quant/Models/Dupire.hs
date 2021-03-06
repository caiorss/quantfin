{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Quant.Models.Dupire (
    Dupire (..)
) where

import Quant.Time
import Quant.Types
import Data.Random
import Control.Monad.State
import Quant.MonteCarlo
import Quant.YieldCurve

-- | 'Dupire' represents a Dupire-style local vol model.
data Dupire = forall a b . (YieldCurve a, YieldCurve b) => Dupire {
   dupireInitial     ::  Double -- ^ Initial asset level
 , dupireFunc        ::  Time -> Double -> Double -- ^ Local vol function taking a time to maturity and a level
 , dupireForwardGen  ::  a  -- ^ 'YieldCurve' to generate forwards
 , dupireDiscounter  ::  b } -- ^ 'YieldCurve' to generate discount rates

instance Discretize Dupire Observables1 where
    initialize (Dupire s _ _ _) = put (Observables1 s, Time 0)
    {-# INLINE initialize #-}

    evolve' d@(Dupire _ f _ _) t2 anti = do
        (Observables1 stateVal, t1) <- get
        fwd <- forwardGen d t2
        let vol   = f t1 stateVal
            t     = timeDiff t1 t2
            grwth = (fwd - vol * vol / 2) * t
        normResid <- lift stdNormal
        let s' | anti      = stateVal * exp (grwth - normResid*vol*sqrt t)
               | otherwise = stateVal * exp (grwth - normResid*vol*sqrt t)
        put (Observables1 s', t2)
    {-# INLINE evolve' #-}

    discount (Dupire _ _ _ dsc) t = return $ disc dsc t
    {-# INLINE discount #-}

    forwardGen (Dupire _ _ fg _) t2 = do
        t1 <- gets snd
        return $ forward fg t1 t2
    {-# INLINE forwardGen #-}