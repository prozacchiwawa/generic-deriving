{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeSynonymInstances #-}

#if __GLASGOW_HASKELL__ >= 711
{-# LANGUAGE Safe #-}
#elif __GLASGOW_HASKELL__ >= 701
{-# LANGUAGE Trustworthy #-}
#endif

module Generics.Deriving.Base.Internal (
-- * Introduction
--
-- |
--
-- Datatype-generic functions are are based on the idea of converting values of
-- a datatype @T@ into corresponding values of a (nearly) isomorphic type @'Rep' T@.
-- The type @'Rep' T@ is
-- built from a limited set of type constructors, all provided by this module. A
-- datatype-generic function is then an overloaded function with instances
-- for most of these type constructors, together with a wrapper that performs
-- the mapping between @T@ and @'Rep' T@. By using this technique, we merely need
-- a few generic instances in order to implement functionality that works for any
-- representable type.
--
-- Representable types are collected in the 'Generic' class, which defines the
-- associated type 'Rep' as well as conversion functions 'from' and 'to'.
-- Typically, you will not define 'Generic' instances by hand, but have the compiler
-- derive them for you.

-- ** Representing datatypes
--
-- |
--
-- The key to defining your own datatype-generic functions is to understand how to
-- represent datatypes using the given set of type constructors.
--
-- Let us look at an example first:
--
-- @
-- data Tree a = Leaf a | Node (Tree a) (Tree a)
--   deriving 'Generic'
-- @
--
-- The above declaration (which requires the language pragma @DeriveGeneric@)
-- causes the following representation to be generated:
--
-- @
-- class 'Generic' (Tree a) where
--   type 'Rep' (Tree a) =
--     'D1' D1Tree
--       ('C1' C1_0Tree
--          ('S1' 'NoSelector' ('Par0' a))
--        ':+:'
--        'C1' C1_1Tree
--          ('S1' 'NoSelector' ('Rec0' (Tree a))
--           ':*:'
--           'S1' 'NoSelector' ('Rec0' (Tree a))))
--   ...
-- @
--
-- /Hint:/ You can obtain information about the code being generated from GHC by passing
-- the @-ddump-deriv@ flag. In GHCi, you can expand a type family such as 'Rep' using
-- the @:kind!@ command.
--
#if 0
-- /TODO:/ Newer GHC versions abandon the distinction between 'Par0' and 'Rec0' and will
-- use 'Rec0' everywhere.
--
#endif
-- This is a lot of information! However, most of it is actually merely meta-information
-- that makes names of datatypes and constructors and more available on the type level.
--
-- Here is a reduced representation for 'Tree' with nearly all meta-information removed,
-- for now keeping only the most essential aspects:
--
-- @
-- instance 'Generic' (Tree a) where
--   type 'Rep' (Tree a) =
--     'Par0' a
--     ':+:'
--     ('Rec0' (Tree a) ':*:' 'Rec0' (Tree a))
-- @
--
-- The @Tree@ datatype has two constructors. The representation of individual constructors
-- is combined using the binary type constructor ':+:'.
--
-- The first constructor consists of a single field, which is the parameter @a@. This is
-- represented as @'Par0' a@.
--
-- The second constructor consists of two fields. Each is a recursive field of type @Tree a@,
-- represented as @'Rec0' (Tree a)@. Representations of individual fields are combined using
-- the binary type constructor ':*:'.
--
-- Now let us explain the additional tags being used in the complete representation:
--
--    * The @'S1' 'NoSelector'@ indicates that there is no record field selector associated with
--      this field of the constructor.
--
--    * The @'C1' C1_0Tree@ and @'C1' C1_1Tree@ invocations indicate that the enclosed part is
--      the representation of the first and second constructor of datatype @Tree@, respectively.
--      Here, @C1_0Tree@ and @C1_1Tree@ are datatypes generated by the compiler as part of
--      @deriving 'Generic'@. These datatypes are proxy types with no values. They are useful
--      because they are instances of the type class 'Constructor'. This type class can be used
--      to obtain information about the constructor in question, such as its name
--      or infix priority.
--
--    * The @'D1' D1Tree@ tag indicates that the enclosed part is the representation of the
--      datatype @Tree@. Again, @D1Tree@ is a datatype generated by the compiler. It is a
--      proxy type, and is useful by being an instance of class 'Datatype', which
--      can be used to obtain the name of a datatype, the module it has been defined in, and
--      whether it has been defined using @data@ or @newtype@.

-- ** Derived and fundamental representation types
--
-- |
--
-- There are many datatype-generic functions that do not distinguish between positions that
-- are parameters or positions that are recursive calls. There are also many datatype-generic
-- functions that do not care about the names of datatypes and constructors at all. To keep
-- the number of cases to consider in generic functions in such a situation to a minimum,
-- it turns out that many of the type constructors introduced above are actually synonyms,
-- defining them to be variants of a smaller set of constructors.

-- *** Individual fields of constructors: 'K1'
--
-- |
--
-- The type constructors 'Par0' and 'Rec0' are variants of 'K1':
--
-- @
-- type 'Par0' = 'K1' 'P'
-- type 'Rec0' = 'K1' 'R'
-- @
--
-- Here, 'P' and 'R' are type-level proxies again that do not have any associated values.

-- *** Meta information: 'M1'
--
-- |
--
-- The type constructors 'S1', 'C1' and 'D1' are all variants of 'M1':
--
-- @
-- type 'S1' = 'M1' 'S'
-- type 'C1' = 'M1' 'C'
-- type 'D1' = 'M1' 'D'
-- @
--
-- The types 'S', 'C' and 'R' are once again type-level proxies, just used to create
-- several variants of 'M1'.

-- *** Additional generic representation type constructors
--
-- |
--
-- Next to 'K1', 'M1', ':+:' and ':*:' there are a few more type constructors that occur
-- in the representations of other datatypes.

-- **** Empty datatypes: 'V1'
--
-- |
--
-- For empty datatypes, 'V1' is used as a representation. For example,
--
-- @
-- data Empty deriving 'Generic'
-- @
--
-- yields
--
-- @
-- instance 'Generic' Empty where
--   type 'Rep' Empty = 'D1' D1Empty 'V1'
-- @

-- **** Constructors without fields: 'U1'
--
-- |
--
-- If a constructor has no arguments, then 'U1' is used as its representation. For example
-- the representation of 'Bool' is
--
-- @
-- instance 'Generic' Bool where
--   type 'Rep' Bool =
--     'D1' D1Bool
--       ('C1' C1_0Bool 'U1' ':+:' 'C1' C1_1Bool 'U1')
-- @

-- *** Representation of types with many constructors or many fields
--
-- |
--
-- As ':+:' and ':*:' are just binary operators, one might ask what happens if the
-- datatype has more than two constructors, or a constructor with more than two
-- fields. The answer is simple: the operators are used several times, to combine
-- all the constructors and fields as needed. However, users /should not rely on
-- a specific nesting strategy/ for ':+:' and ':*:' being used. The compiler is
-- free to choose any nesting it prefers. (In practice, the current implementation
-- tries to produce a more or less balanced nesting, so that the traversal of the
-- structure of the datatype from the root to a particular component can be performed
-- in logarithmic rather than linear time.)

-- ** Defining datatype-generic functions
--
-- |
--
-- A datatype-generic function comprises two parts:
--
--    1. /Generic instances/ for the function, implementing it for most of the representation
--       type constructors introduced above.
--
--    2. A /wrapper/ that for any datatype that is in `Generic`, performs the conversion
--       between the original value and its `Rep`-based representation and then invokes the
--       generic instances.
--
-- As an example, let us look at a function 'encode' that produces a naive, but lossless
-- bit encoding of values of various datatypes. So we are aiming to define a function
--
-- @
-- encode :: 'Generic' a => a -> [Bool]
-- @
--
-- where we use 'Bool' as our datatype for bits.
--
-- For part 1, we define a class @Encode'@. Perhaps surprisingly, this class is parameterized
-- over a type constructor @f@ of kind @* -> *@. This is a technicality: all the representation
-- type constructors operate with kind @* -> *@ as base kind. But the type argument is never
-- being used. This may be changed at some point in the future. The class has a single method,
-- and we use the type we want our final function to have, but we replace the occurrences of
-- the generic type argument @a@ with @f p@ (where the @p@ is any argument; it will not be used).
--
-- > class Encode' f where
-- >   encode' :: f p -> [Bool]
--
-- With the goal in mind to make @encode@ work on @Tree@ and other datatypes, we now define
-- instances for the representation type constructors 'V1', 'U1', ':+:', ':*:', 'K1', and 'M1'.

-- *** Definition of the generic representation types
--
-- |
--
-- In order to be able to do this, we need to know the actual definitions of these types:
--
-- @
-- data    'V1'        p                       -- lifted version of Empty
-- data    'U1'        p = 'U1'                  -- lifted version of ()
-- data    (':+:') f g p = 'L1' (f p) | 'R1' (g p) -- lifted version of 'Either'
-- data    (':*:') f g p = (f p) ':*:' (g p)     -- lifted version of (,)
-- newtype 'K1'    i c p = 'K1' { 'unK1' :: c }    -- a container for a c
-- newtype 'M1'  i t f p = 'M1' { 'unM1' :: f p }  -- a wrapper
-- @
--
-- So, 'U1' is just the unit type, ':+:' is just a binary choice like 'Either',
-- ':*:' is a binary pair like the pair constructor @(,)@, and 'K1' is a value
-- of a specific type @c@, and 'M1' wraps a value of the generic type argument,
-- which in the lifted world is an @f p@ (where we do not care about @p@).

-- *** Generic instances
--
-- |
--
-- The instance for 'V1' is slightly awkward (but also rarely used):
--
-- @
-- instance Encode' 'V1' where
--   encode' x = undefined
-- @
--
-- There are no values of type @V1 p@ to pass (except undefined), so this is
-- actually impossible. One can ask why it is useful to define an instance for
-- 'V1' at all in this case? Well, an empty type can be used as an argument to
-- a non-empty type, and you might still want to encode the resulting type.
-- As a somewhat contrived example, consider @[Empty]@, which is not an empty
-- type, but contains just the empty list. The 'V1' instance ensures that we
-- can call the generic function on such types.
--
-- There is exactly one value of type 'U1', so encoding it requires no
-- knowledge, and we can use zero bits:
--
-- @
-- instance Encode' 'U1' where
--   encode' 'U1' = []
-- @
--
-- In the case for ':+:', we produce 'False' or 'True' depending on whether
-- the constructor of the value provided is located on the left or on the right:
--
-- @
-- instance (Encode' f, Encode' g) => Encode' (f ':+:' g) where
--   encode' ('L1' x) = False : encode' x
--   encode' ('R1' x) = True  : encode' x
-- @
--
-- In the case for ':*:', we append the encodings of the two subcomponents:
--
-- @
-- instance (Encode' f, Encode' g) => Encode' (f ':*:' g) where
--   encode' (x ':*:' y) = encode' x ++ encode' y
-- @
--
-- The case for 'K1' is rather interesting. Here, we call the final function
-- 'encode' that we yet have to define, recursively. We will use another type
-- class 'Encode' for that function:
--
-- @
-- instance (Encode c) => Encode' ('K1' i c) where
--   encode' ('K1' x) = encode x
-- @
--
-- Note how 'Par0' and 'Rec0' both being mapped to 'K1' allows us to define
-- a uniform instance here.
--
-- Similarly, we can define a uniform instance for 'M1', because we completely
-- disregard all meta-information:
--
-- @
-- instance (Encode' f) => Encode' ('M1' i t f) where
--   encode' ('M1' x) = encode' x
-- @
--
-- Unlike in 'K1', the instance for 'M1' refers to 'encode'', not 'encode'.

-- *** The wrapper and generic default
--
-- |
--
-- We now define class 'Encode' for the actual 'encode' function:
--
-- @
-- class Encode a where
--   encode :: a -> [Bool]
--   default encode :: ('Generic' a) => a -> [Bool]
--   encode x = encode' ('from' x)
-- @
--
-- The incoming 'x' is converted using 'from', then we dispatch to the
-- generic instances using 'encode''. We use this as a default definition
-- for 'encode'. We need the 'default encode' signature because ordinary
-- Haskell default methods must not introduce additional class constraints,
-- but our generic default does.
--
-- Defining a particular instance is now as simple as saying
--
-- @
-- instance (Encode a) => Encode (Tree a)
-- @
--
#if 0
-- /TODO:/ Add usage example?
--
#endif
-- The generic default is being used. In the future, it will hopefully be
-- possible to use @deriving Encode@ as well, but GHC does not yet support
-- that syntax for this situation.
--
-- Having 'Encode' as a class has the advantage that we can define
-- non-generic special cases, which is particularly useful for abstract
-- datatypes that have no structural representation. For example, given
-- a suitable integer encoding function 'encodeInt', we can define
--
-- @
-- instance Encode Int where
--   encode = encodeInt
-- @

-- *** Omitting generic instances
--
-- |
--
-- It is not always required to provide instances for all the generic
-- representation types, but omitting instances restricts the set of
-- datatypes the functions will work for:
--
--    * If no ':+:' instance is given, the function may still work for
--      empty datatypes or datatypes that have a single constructor,
--      but will fail on datatypes with more than one constructor.
--
--    * If no ':*:' instance is given, the function may still work for
--      datatypes where each constructor has just zero or one field,
--      in particular for enumeration types.
--
--    * If no 'K1' instance is given, the function may still work for
--      enumeration types, where no constructor has any fields.
--
--    * If no 'V1' instance is given, the function may still work for
--      any datatype that is not empty.
--
--    * If no 'U1' instance is given, the function may still work for
--      any datatype where each constructor has at least one field.
--
-- An 'M1' instance is always required (but it can just ignore the
-- meta-information, as is the case for 'encode' above).
#if 0
-- *** Using meta-information
--
-- |
--
-- TODO
#endif
-- ** Generic constructor classes
--
-- |
--
-- Datatype-generic functions as defined above work for a large class
-- of datatypes, including parameterized datatypes. (We have used 'Tree'
-- as our example above, which is of kind @* -> *@.) However, the
-- 'Generic' class ranges over types of kind @*@, and therefore, the
-- resulting generic functions (such as 'encode') must be parameterized
-- by a generic type argument of kind @*@.
--
-- What if we want to define generic classes that range over type
-- constructors (such as 'Functor', 'Traversable', or 'Foldable')?

-- *** The 'Generic1' class
--
-- |
--
-- Like 'Generic', there is a class 'Generic1' that defines a
-- representation 'Rep1' and conversion functions 'from1' and 'to1',
-- only that 'Generic1' ranges over types of kind @* -> *@.
-- The 'Generic1' class is also derivable.
--
-- The representation 'Rep1' is ever so slightly different from 'Rep'.
-- Let us look at 'Tree' as an example again:
--
-- @
-- data Tree a = Leaf a | Node (Tree a) (Tree a)
--   deriving 'Generic1'
-- @
--
-- The above declaration causes the following representation to be generated:
--
-- class 'Generic1' Tree where
--   type 'Rep1' Tree =
--     'D1' D1Tree
--       ('C1' C1_0Tree
--          ('S1' 'NoSelector' 'Par1')
--        ':+:'
--        'C1' C1_1Tree
--          ('S1' 'NoSelector' ('Rec1' Tree)
--           ':*:'
--           'S1' 'NoSelector' ('Rec1' Tree)))
--   ...
--
-- The representation reuses 'D1', 'C1', 'S1' (and thereby 'M1') as well
-- as ':+:' and ':*:' from 'Rep'. (This reusability is the reason that we
-- carry around the dummy type argument for kind-@*@-types, but there are
-- already enough different names involved without duplicating each of
-- these.)
--
-- What's different is that we now use 'Par1' to refer to the parameter
-- (and that parameter, which used to be @a@), is not mentioned explicitly
-- by name anywhere; and we use 'Rec1' to refer to a recursive use of @Tree a@.

-- *** Representation of @* -> *@ types
--
-- |
--
-- Unlike 'Par0' and 'Rec0', the 'Par1' and 'Rec1' type constructors do not
-- map to 'K1'. They are defined directly, as follows:
--
-- @
-- newtype 'Par1'   p = 'Par1' { 'unPar1' ::   p } -- gives access to parameter p
-- newtype 'Rec1' f p = 'Rec1' { 'unRec1' :: f p } -- a wrapper
-- @
--
-- In 'Par1', the parameter @p@ is used for the first time, whereas 'Rec1' simply
-- wraps an application of @f@ to @p@.
--
-- Note that 'K1' (in the guise of 'Rec0') can still occur in a 'Rep1' representation,
-- namely when the datatype has a field that does not mention the parameter.
--
-- The declaration
--
-- @
-- data WithInt a = WithInt Int a
--   deriving 'Generic1'
-- @
--
-- yields
--
-- @
-- class 'Rep1' WithInt where
--   type 'Rep1' WithInt =
--     'D1' D1WithInt
--       ('C1' C1_0WithInt
--         ('S1' 'NoSelector' ('Rec0' Int)
--          ':*:'
--          'S1' 'NoSelector' 'Par1'))
-- @
--
-- If the parameter @a@ appears underneath a composition of other type constructors,
-- then the representation involves composition, too:
--
-- @
-- data Rose a = Fork a [Rose a]
-- @
--
-- yields
--
-- @
-- class 'Rep1' Rose where
--   type 'Rep1' Rose =
--     'D1' D1Rose
--       ('C1' C1_0Rose
--         ('S1' 'NoSelector' 'Par1'
--          ':*:'
--          'S1' 'NoSelector' ([] ':.:' 'Rec1' Rose)
-- @
--
-- where
--
-- @
-- newtype (':.:') f g p = 'Comp1' { 'unComp1' :: f (g p) }
-- @

-- *** Representation of unlifted types
--
-- |
--
-- If one were to attempt to derive a Generic instance for a datatype with an
-- unlifted argument (for example, 'Int#'), one might expect the occurrence of
-- the 'Int#' argument to be marked with @'Rec0' 'Int#'@. This won't work,
-- though, since 'Int#' is of kind @#@ and 'Rec0' expects a type of kind @*@.
-- In fact, polymorphism over unlifted types is disallowed completely.
--
-- One solution would be to represent an occurrence of 'Int#' with 'Rec0 Int'
-- instead. With this approach, however, the programmer has no way of knowing
-- whether the 'Int' is actually an 'Int#' in disguise.
--
-- Instead of reusing 'Rec0', a separate data family 'URec' is used to mark
-- occurrences of common unlifted types:
--
-- @
-- data family URec a p
--
-- data instance 'URec' ('Ptr' ()) p = 'UAddr'   { 'uAddr#'   :: 'Addr#'   }
-- data instance 'URec' 'Char'     p = 'UChar'   { 'uChar#'   :: 'Char#'   }
-- data instance 'URec' 'Double'   p = 'UDouble' { 'uDouble#' :: 'Double#' }
-- data instance 'URec' 'Int'      p = 'UFloat'  { 'uFloat#'  :: 'Float#'  }
-- data instance 'URec' 'Float'    p = 'UInt'    { 'uInt#'    :: 'Int#'    }
-- data instance 'URec' 'Word'     p = 'UWord'   { 'uWord#'   :: 'Word#'   }
-- @
--
-- Several type synonyms are provided for convenience:
--
-- @
-- type 'UAddr'   = 'URec' ('Ptr' ())
-- type 'UChar'   = 'URec' 'Char'
-- type 'UDouble' = 'URec' 'Double'
-- type 'UFloat'  = 'URec' 'Float'
-- type 'UInt'    = 'URec' 'Int'
-- type 'UWord'   = 'URec' 'Word'
-- @
--
-- The declaration
--
-- @
-- data IntHash = IntHash Int#
--   deriving 'Generic'
-- @
--
-- yields
--
-- @
-- instance 'Generic' IntHash where
--   type 'Rep' IntHash =
--     'D1' D1IntHash
--       ('C1' C1_0IntHash
--         ('S1' 'NoSelector' 'UInt'))
-- @
--
-- Currently, only the six unlifted types listed above are generated, but this
-- may be extended to encompass more unlifted types in the future.
#if 0
-- *** Limitations
--
-- |
--
-- /TODO/
--
-- /TODO:/ Also clear up confusion about 'Rec0' and 'Rec1' not really indicating recursion.
--
#endif
#if !(MIN_VERSION_base(4,4,0))
  -- * Generic representation types
    V1, U1(..), Par1(..), Rec1(..), K1(..), M1(..)
  , (:+:)(..), (:*:)(..), (:.:)(..)

  -- ** Synonyms for convenience
  , Rec0, Par0, R, P
  , D1, C1, S1, D, C, S

  -- * Meta-information
  , Datatype(..), Constructor(..), Selector(..), NoSelector
  , Fixity(..), Associativity(..), Arity(..), prec

  -- * Generic type classes
  , Generic(..), Generic1(..),

#else
  module GHC.Generics,
#endif
#if !(MIN_VERSION_base(4,9,0))
  -- ** Unboxed representation types
    URec(..)
--    , UAddr, UChar, UDouble, UFloat, UInt, UWord
#endif
  ) where


#if MIN_VERSION_base(4,4,0)
import GHC.Generics
#else
import Control.Applicative ( Alternative(..) )
import Control.Monad ( MonadPlus(..) )
import Control.Monad.Fix ( MonadFix(..), fix )
import Data.Data ( Data(..), DataType, constrIndex, mkDataType )
import Data.Ix ( Ix )
import Text.ParserCombinators.ReadPrec (pfail)
import Text.Read ( Read(..), parens, readListDefault, readListPrecDefault )
#endif

#if !(MIN_VERSION_base(4,8,0))
import Control.Applicative ( Applicative(..) )
import Data.Foldable ( Foldable(..) )
import Data.Monoid ( Monoid(..) )
import Data.Traversable ( Traversable(..) )
import Data.Word ( Word )
#endif

#if !(MIN_VERSION_base(4,9,0))
import Data.Typeable
import GHC.Prim ( Addr#, Char#, Double#, Float#, Int#, Word# )
import GHC.Ptr ( Ptr )
#endif

#if !(MIN_VERSION_base(4,4,0))
--------------------------------------------------------------------------------
-- Representation types
--------------------------------------------------------------------------------

-- | Void: used for datatypes without constructors
data V1 p deriving Typeable

-- Implement these instances by hand to get the desired, maximally lazy behavior.
instance Functor V1 where
  fmap _ !_ = error "Void fmap"

instance Foldable V1 where
  foldr _ z _ = z
  foldMap _ _ = mempty

instance Traversable V1 where
  traverse _ x = pure (case x of !_ -> error "Void traverse")

instance Eq (V1 p) where
  _ == _ = True

instance Data p => Data (V1 p) where
  gfoldl _ _ !_ = error "Void gfoldl"
  gunfold _ _ c = case constrIndex c of
                    _ -> error "Void gunfold"
  toConstr !_ = error "Void toConstr"
  dataTypeOf _ = v1DataType
  dataCast1 f = gcast1 f

v1DataType :: DataType
v1DataType = mkDataType "V1" []

instance Ord (V1 p) where
  compare _ _ = EQ

instance Show (V1 p) where
  showsPrec _ !_ = error "Void showsPrec"

-- Implement Read instance manually to get around an old GHC bug
-- (Trac #7931)
instance Read (V1 p) where
  readPrec     = parens pfail
  readList     = readListDefault
  readListPrec = readListPrecDefault

-- | Unit: used for constructors without arguments
data U1 p = U1
  deriving (Eq, Ord, Read, Show, Data, Typeable)

instance Functor U1 where
  fmap _ _ = U1

instance Applicative U1 where
  pure _ = U1
  _ <*> _ = U1

instance Alternative U1 where
  empty = U1
  _ <|> _ = U1

instance Monad U1 where
  return _ = U1
  _ >>= _ = U1

instance MonadPlus U1 where
  mzero = U1
  mplus _ _ = U1

instance Foldable U1 where
  foldMap _ _ = mempty
  {-# INLINE foldMap #-}
  fold _ = mempty
  {-# INLINE fold #-}
  foldr _ z _ = z
  {-# INLINE foldr #-}
  foldl _ z _ = z
  {-# INLINE foldl #-}
  foldl1 _ _ = error "foldl1: U1"
  foldr1 _ _ = error "foldr1: U1"

instance Traversable U1 where
  traverse _ _ = pure U1
  {-# INLINE traverse #-}
  sequenceA _ = pure U1
  {-# INLINE sequenceA #-}
  mapM _ _ = return U1
  {-# INLINE mapM #-}
  sequence _ = return U1
  {-# INLINE sequence #-}

-- | Used for marking occurrences of the parameter
newtype Par1 p = Par1 { unPar1 :: p }
  deriving (Eq, Ord, Read, Show, Functor, Foldable, Traversable, Data, Typeable)

instance Applicative Par1 where
  pure a = Par1 a
  Par1 f <*> Par1 x = Par1 (f x)

instance Monad Par1 where
  return a = Par1 a
  Par1 x >>= f = f x

instance MonadFix Par1 where
  mfix f = Par1 (fix (unPar1 . f))

-- | Recursive calls of kind * -> *
newtype Rec1 f p = Rec1 { unRec1 :: f p }
  deriving (Eq, Ord, Read, Show, Functor, Foldable, Traversable, Data)

instance Typeable1 f => Typeable1 (Rec1 f) where
  typeOf1 t = mkTyConApp rec1TyCon [typeOf1 (f t)]
    where
      f :: Rec1 f a -> f a
      f = undefined

rec1TyCon :: TyCon
rec1TyCon = mkTyCon "Generics.Deriving.Base.Internal.Rec1"

instance Applicative f => Applicative (Rec1 f) where
  pure a = Rec1 (pure a)
  Rec1 f <*> Rec1 x = Rec1 (f <*> x)

instance Alternative f => Alternative (Rec1 f) where
  empty = Rec1 empty
  Rec1 l <|> Rec1 r = Rec1 (l <|> r)

instance Monad f => Monad (Rec1 f) where
  return a = Rec1 (return a)
  Rec1 x >>= f = Rec1 (x >>= \a -> unRec1 (f a))

instance MonadFix f => MonadFix (Rec1 f) where
  mfix f = Rec1 (mfix (unRec1 . f))

instance MonadPlus f => MonadPlus (Rec1 f) where
  mzero = Rec1 mzero
  mplus (Rec1 a) (Rec1 b) = Rec1 (mplus a b)

-- | Constants, additional parameters and recursion of kind *
newtype K1 i c p = K1 { unK1 :: c }
  deriving (Eq, Ord, Read, Show, Functor, Data, Typeable)

instance Foldable (K1 i c) where
  foldr _ z K1{} = z
  foldMap _ K1{} = mempty

instance Traversable (K1 i c) where
  traverse _ (K1 c) = pure (K1 c)

-- | Meta-information (constructor names, etc.)
newtype M1 i c f p = M1 { unM1 :: f p }
  deriving (Eq, Ord, Read, Show, Functor, Foldable, Traversable, Data)

instance (Typeable i, Typeable c, Typeable1 f) => Typeable1 (M1 i c f) where
  typeOf1 t = mkTyConApp m1TyCon [typeOf (i t), typeOf (c t), typeOf1 (f t)]
    where
      i :: M1 i c f p -> i
      i = undefined

      c :: M1 i c f p -> c
      c = undefined

      f :: M1 i c f p -> f p
      f = undefined

m1TyCon :: TyCon
m1TyCon = mkTyCon "Generics.Deriving.Base.Internal.M1"

instance Applicative f => Applicative (M1 i c f) where
  pure a = M1 (pure a)
  M1 f <*> M1 x = M1 (f <*> x)

instance Alternative f => Alternative (M1 i c f) where
  empty = M1 empty
  M1 l <|> M1 r = M1 (l <|> r)

instance Monad f => Monad (M1 i c f) where
  return a = M1 (return a)
  M1 x >>= f = M1 (x >>= \a -> unM1 (f a))

instance MonadPlus f => MonadPlus (M1 i c f) where
  mzero = M1 mzero
  mplus (M1 a) (M1 b) = M1 (mplus a b)

instance MonadFix f => MonadFix (M1 i c f) where
  mfix f = M1 (mfix (unM1. f))

-- | Sums: encode choice between constructors
infixr 5 :+:
data (:+:) f g p = L1 (f p) | R1 (g p)
  deriving (Eq, Ord, Read, Show, Functor, Foldable, Traversable, Data)

instance (Typeable1 f, Typeable1 g) => Typeable1 (f :+: g) where
  typeOf1 t = mkTyConApp conSumTyCon [typeOf1 (f t), typeOf1 (g t)]
    where
      f :: (f :+: g) p -> f p
      f = undefined

      g :: (f :+: g) p -> g p
      g = undefined

conSumTyCon :: TyCon
conSumTyCon = mkTyCon "Generics.Deriving.Base.Internal.:+:"

-- | Products: encode multiple arguments to constructors
infixr 6 :*:
data (:*:) f g p = f p :*: g p
  deriving (Eq, Ord, Read, Show, Functor, Foldable, Traversable, Data)

instance (Typeable1 f, Typeable1 g) => Typeable1 (f :*: g) where
  typeOf1 t = mkTyConApp conProductTyCon [typeOf1 (f t), typeOf1 (g t)]
    where
      f :: (f :*: g) p -> f p
      f = undefined

      g :: (f :*: g) p -> g p
      g = undefined

conProductTyCon :: TyCon
conProductTyCon = mkTyCon "Generics.Deriving.Base.Internal.:*:"

instance (Applicative f, Applicative g) => Applicative (f :*: g) where
  pure a = pure a :*: pure a
  (f :*: g) <*> (x :*: y) = (f <*> x) :*: (g <*> y)

instance (Alternative f, Alternative g) => Alternative (f :*: g) where
  empty = empty :*: empty
  (x1 :*: y1) <|> (x2 :*: y2) = (x1 <|> x2) :*: (y1 <|> y2)

instance (Monad f, Monad g) => Monad (f :*: g) where
  return a = return a :*: return a
  (m :*: n) >>= f = (m >>= \a -> fstP (f a)) :*: (n >>= \a -> sndP (f a))
    where
      fstP (a :*: _) = a
      sndP (_ :*: b) = b

instance (MonadFix f, MonadFix g) => MonadFix (f :*: g) where
  mfix f = (mfix (fstP . f)) :*: (mfix (sndP . f))
    where
      fstP (a :*: _) = a
      sndP (_ :*: b) = b

instance (MonadPlus f, MonadPlus g) => MonadPlus (f :*: g) where
  mzero = mzero :*: mzero
  (x1 :*: y1) `mplus` (x2 :*: y2) =  (x1 `mplus` x2) :*: (y1 `mplus` y2)

-- | Composition of functors
infixr 7 :.:
newtype (:.:) f g p = Comp1 { unComp1 :: f (g p) }
  deriving (Eq, Ord, Read, Show, Functor, Foldable, Traversable, Data)

instance (Typeable1 f, Typeable1 g) => Typeable1 (f :.: g) where
  typeOf1 t = mkTyConApp conComposeTyCon [typeOf1 (f t), typeOf1 (g t)]
    where
      f :: (f :.: g) p -> f p
      f = undefined

      g :: (f :.: g) p -> g p
      g = undefined

conComposeTyCon :: TyCon
conComposeTyCon = mkTyCon "Generics.Deriving.Base.Internal.:.:"

instance (Applicative f, Applicative g) => Applicative (f :.: g) where
  pure x = Comp1 (pure (pure x))
  Comp1 f <*> Comp1 x = Comp1 (fmap (<*>) f <*> x)

instance (Alternative f, Applicative g) => Alternative (f :.: g) where
  empty = Comp1 empty
  Comp1 x <|> Comp1 y = Comp1 (x <|> y)

-- | Tag for K1: recursion (of kind *)
data R
  deriving Typeable
-- | Tag for K1: parameters (other than the last)
data P
  deriving Typeable

-- | Type synonym for encoding recursion (of kind *)
type Rec0  = K1 R
-- | Type synonym for encoding parameters (other than the last)
type Par0  = K1 P

-- | Tag for M1: datatype
data D
  deriving Typeable
-- | Tag for M1: constructor
data C
  deriving Typeable
-- | Tag for M1: record selector
data S
  deriving Typeable

-- | Type synonym for encoding meta-information for datatypes
type D1 = M1 D

-- | Type synonym for encoding meta-information for constructors
type C1 = M1 C

-- | Type synonym for encoding meta-information for record selectors
type S1 = M1 S

-- | Class for datatypes that represent datatypes
class Datatype d where
  -- | The name of the datatype, fully qualified
  datatypeName :: t d (f :: * -> *) a -> String
  moduleName   :: t d (f :: * -> *) a -> String

-- | Class for datatypes that represent records
class Selector s where
  -- | The name of the selector
  selName :: t s (f :: * -> *) a -> String

-- | Used for constructor fields without a name
data NoSelector
  deriving Typeable

instance Selector NoSelector where selName _ = ""

-- | Class for datatypes that represent data constructors
class Constructor c where
  -- | The name of the constructor
  conName :: t c (f :: * -> *) a -> String

  -- | The fixity of the constructor
  conFixity :: t c (f :: * -> *) a -> Fixity
  conFixity = const Prefix

  -- | Marks if this constructor is a record
  conIsRecord :: t c (f :: * -> *) a -> Bool
  conIsRecord = const False


-- | Datatype to represent the arity of a tuple.
data Arity = NoArity | Arity Int
  deriving (Eq, Show, Ord, Read, Typeable)

-- | Datatype to represent the fixity of a constructor. An infix
-- | declaration directly corresponds to an application of 'Infix'.
data Fixity = Prefix | Infix Associativity Int
  deriving (Eq, Show, Ord, Read, Data, Typeable)

-- | Get the precedence of a fixity value.
prec :: Fixity -> Int
prec Prefix      = 10
prec (Infix _ n) = n

-- | Datatype to represent the associativy of a constructor
data Associativity =  LeftAssociative
                   |  RightAssociative
                   |  NotAssociative
  deriving (Eq, Show, Ord, Read, Bounded, Enum, Ix, Data, Typeable)

-- | Representable types of kind *
class Generic a where
  type Rep a :: * -> *
  -- | Convert from the datatype to its representation
  from  :: a -> Rep a x
  -- | Convert from the representation to the datatype
  to    :: Rep a x -> a

-- | Representable types of kind * -> *
class Generic1 f where
  type Rep1 f :: * -> *
  -- | Convert from the datatype to its representation
  from1  :: f a -> Rep1 f a
  -- | Convert from the representation to the datatype
  to1    :: Rep1 f a -> f a

#endif

#if !(MIN_VERSION_base(4,9,0))
-- | Constants of kind @#@
data family URec (a :: *) (p :: *)

# if MIN_VERSION_base(4,7,0)
deriving instance Typeable URec
# else
instance Typeable2 URec where
  typeOf2 _ =
#  if MIN_VERSION_base(4,4,0)
      mkTyConApp (mkTyCon3 "generic-deriving"
                           "Generics.Deriving.Base.Internal"
                           "URec") []
#  else
      mkTyConApp (mkTyCon "Generics.Deriving.Base.Internal.URec") []
#  endif
# endif

-- | Used for marking occurrences of 'Addr#'
data instance URec (Ptr ()) p = UAddr { uAddr# :: Addr# }
  deriving (Eq, Ord)

instance Functor (URec (Ptr ())) where
  fmap _ (UAddr a) = UAddr a

instance Foldable (URec (Ptr ())) where
  foldr _ z UAddr{} = z
  foldMap _ UAddr{} = mempty

instance Traversable (URec (Ptr ())) where
  traverse _ (UAddr a) = pure (UAddr a)

-- | Used for marking occurrences of 'Char#'
data instance URec Char p = UChar { uChar# :: Char# }
  deriving (Eq, Ord, Show)

instance Functor (URec Char) where
  fmap _ (UChar c) = UChar c

instance Foldable (URec Char) where
  foldr _ z UChar{} = z
  foldMap _ UChar{} = mempty

instance Traversable (URec Char) where
  traverse _ (UChar c) = pure (UChar c)

-- | Used for marking occurrences of 'Double#'
data instance URec Double p = UDouble { uDouble# :: Double# }
  deriving (Eq, Ord, Show)

instance Functor (URec Double) where
  fmap _ (UDouble d) = UDouble d

instance Foldable (URec Double) where
  foldr _ z UDouble{} = z
  foldMap _ UDouble{} = mempty

instance Traversable (URec Double) where
  traverse _ (UDouble d) = pure (UDouble d)

-- | Used for marking occurrences of 'Float#'
data instance URec Float p = UFloat { uFloat# :: Float# }
  deriving (Eq, Ord, Show)

instance Functor (URec Float) where
  fmap _ (UFloat f) = UFloat f

instance Foldable (URec Float) where
  foldr _ z UFloat{} = z
  foldMap _ UFloat{} = mempty

instance Traversable (URec Float) where
  traverse _ (UFloat f) = pure (UFloat f)

-- | Used for marking occurrences of 'Int#'
data instance URec Int p = UInt { uInt# :: Int# }
  deriving (Eq, Ord, Show)

instance Functor (URec Int) where
  fmap _ (UInt i) = UInt i

instance Foldable (URec Int) where
  foldr _ z UInt{} = z
  foldMap _ UInt{} = mempty

instance Traversable (URec Int) where
  traverse _ (UInt i) = pure (UInt i)

-- | Used for marking occurrences of 'Word#'
data instance URec Word p = UWord { uWord# :: Word# }
  deriving (Eq, Ord, Show)

instance Functor (URec Word) where
  fmap _ (UWord w) = UWord w

instance Foldable (URec Word) where
  foldr _ z UWord{} = z
  foldMap _ UWord{} = mempty

instance Traversable (URec Word) where
  traverse _ (UWord w) = pure (UWord w)

-- | Type synonym for 'URec': 'Addr#'
type UAddr   = URec (Ptr ())
-- | Type synonym for 'URec': 'Char#'
type UChar   = URec Char
-- | Type synonym for 'URec': 'Double#'
type UDouble = URec Double
-- | Type synonym for 'URec': 'Float#'
type UFloat  = URec Float
-- | Type synonym for 'URec': 'Int#'
type UInt    = URec Int
-- | Type synonym for 'URec': 'Word#'
type UWord   = URec Word
#endif
