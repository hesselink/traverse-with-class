{-# LANGUAGE ConstraintKinds, KindSignatures, MultiParamTypeClasses, RankNTypes, UndecidableInstances, ImplicitParams, ScopedTypeVariables, FlexibleContexts, FlexibleInstances #-}
-- | All of the functions below work only on «interesting» subterms.
-- It is up to the instance writer to decide which subterms are
-- interesting and which subterms should count as immediate. This can
-- also depend on the context @c@.
--
-- The context, denoted @c@, is a constraint (of kind @* -> Constraint@)
-- that provides additional facilities to work with the data. Most
-- functions take an implicit parameter @?c :: p c@; it's
-- used to disambugate which context you are referring to. @p@ can be
-- @Proxy@ from the @tagged@ package or any other suitable type
-- constructor.
--
-- For more information, see:
--
-- [Scrap your boilerplate with class]
-- <http://research.microsoft.com/en-us/um/people/simonpj/papers/hmap/>
--
-- [Generalizing generic fold]
-- <http://ro-che.info/articles/2013-03-11-generalizing-gfoldl.html>

module Data.Generics.Traversable
  (
    -- * Open recursion combinators

    GTraversable(..)
  , gmap
  , gmapM
  , gfoldMap
  , gfoldr
  , gfoldl'

    -- * Closed recursion combinators
  , Rec
  , everywhere
  , everywhere'
  , everywhereM
  , everything
  )
  where

import GHC.Exts (Constraint)

import Control.Applicative
import Control.Monad
import Data.Monoid
import Data.Functor.Identity
import Data.Functor.Constant

import Data.Generics.Traversable.Core
import Data.Generics.Traversable.Instances ()

-- for documentation only
import Data.Foldable
import Data.Traversable

-- | 'Rec' enables \"deep traversals\".
--
-- It is satisfied automatically when its superclass constraints are
-- satisfied — you are not supposed to declare new instances of this class.
class    (GTraversable (Rec c) a, c a) => Rec (c :: * -> Constraint) a
instance (GTraversable (Rec c) a, c a) => Rec (c :: * -> Constraint) a

-- | Generic map over the immediate subterms
gmap
  :: (GTraversable c a, ?c :: p c)
  => (forall d . (c d) => d -> d)
  -> a -> a
gmap f = runIdentity . gtraverse (Identity . f)

-- | Generic monadic map over the immediate subterms
gmapM
  :: (Monad m, GTraversable c a, ?c :: p c)
  => (forall d . (c d) => d -> m d)
  -> a -> m a
gmapM f = unwrapMonad . gtraverse (WrapMonad . f)

-- | Generic monoidal fold over the immediate subterms (cf. 'foldMap' from
-- "Data.Foldable")
gfoldMap
  :: (Monoid r, GTraversable c a, ?c :: p c)
  => (forall d . (c d) => d -> r)
  -> a -> r
gfoldMap f = getConstant . gtraverse (Constant . f)

-- | Generic right fold over the immediate subterms
gfoldr
  :: (GTraversable c a, ?c :: p c)
  => (forall d . (c d) => d -> r -> r)
  -> r -> a -> r
gfoldr f z t = appEndo (gfoldMap (Endo . f) t) z

-- | Generic strict left fold over the immediate subterms
gfoldl'
  :: (GTraversable c a, ?c :: p c)
  => (forall d . (c d) => r -> d -> r)
  -> r -> a -> r
gfoldl' f z0 xs = gfoldr f' id xs z0
  where f' x k z = k $! f z x

data Proxy (c :: * -> Constraint) = Proxy

-- | Apply a transformation everywhere in bottom-up manner
everywhere
  :: forall a c p .
     (Rec c a, ?c :: p c)
  => (forall d. (Rec c d) => d -> d)
  -> a -> a
everywhere f =
  let ?c = Proxy :: Proxy (Rec c) in
  let
    go :: forall a . Rec c a => a -> a
    go = f . gmap go
  in go

-- | Apply a transformation everywhere in top-down manner
everywhere'
  :: forall a c p .
     (Rec c a, ?c :: p c)
  => (forall d. (Rec c d) => d -> d)
  -> a -> a
everywhere' f =
  let ?c = Proxy :: Proxy (Rec c) in
  let
    go :: forall a . Rec c a => a -> a
    go = gmap go . f
  in go

-- | Monadic variation on everywhere
everywhereM
  :: forall m a c p .
     (Monad m, Rec c a, ?c :: p c)
  => (forall d. (Rec c d) => d -> m d)
  -> a -> m a
everywhereM f =
  let ?c = Proxy :: Proxy (Rec c) in
  let
    go :: forall a . Rec c a => a -> m a
    go = f <=< gmapM go
  in go

-- | Strict left fold over all elements, top-down
everything
  :: forall r a c p .
     (Rec c a, ?c :: p c)
  => (r -> r -> r)
  -> (forall d . (Rec c d) => d -> r)
  -> a -> r
everything combine f =
  let ?c = Proxy :: Proxy (Rec c) in
  let
    go :: forall a . Rec c a => a -> r
    go x = gfoldl' (\a y -> combine a (go y)) (f x) x
  in go
