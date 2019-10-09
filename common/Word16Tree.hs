{-# language BangPatterns #-}

module Word16Tree
  ( Word16Tree
  , encode
  , exampleSmall
  , example2000
  , example9000
  , expectedSmall
  ) where

import Data.ByteArray.Builder as B
import Data.Word (Word16)
import Data.Primitive (ByteArray)
import qualified Data.Bytes as Bytes

data Word16Tree
  = Branch !Word16Tree !Word16Tree
  | Leaf {-# UNPACK #-} !Word16

encode :: Word16Tree -> Builder
encode (Leaf w) = B.word16PaddedUpperHex w
encode (Branch a b) =
  B.ascii '('
  <>
  encode a
  <>
  B.ascii ','
  <>
  encode b
  <>
  B.ascii ')'

expectedSmall :: ByteArray
expectedSmall = Bytes.toByteArray $ Bytes.fromAsciiString
  "((AB59,(1F33,2E71)),((((FA9A,247B),890C),(0F13,((55BF,7CF1),389B))),1205))"


exampleSmall :: Word16Tree
exampleSmall = Branch
  (Branch
    (Leaf 0xAB59)
    (Branch
      (Leaf 0x1F33)
      (Leaf 0x2E71)
    )
  )
  (Branch
    (Branch 
      (Branch
        (Branch
          (Leaf 0xFA9A)
          (Leaf 0x247B)
        )
        (Leaf 0x890C)
      )
      (Branch
        (Leaf 0x0F13)
        (Branch
          (Branch
            (Leaf 0x55BF)
            (Leaf 0x7CF1)
          )
          (Leaf 0x389B)
        )
      )
    )
    (Leaf 0x1205)
  )

example2000 :: Word16Tree
{-# noinline example2000 #-}
example2000 = balanced 0 2000

example9000 :: Word16Tree
{-# noinline example9000 #-}
example9000 = balanced 0 9000

balanced :: Word16 -> Word16 -> Word16Tree
balanced !off !n
  | n == 0 = Leaf off
  | n == 1 = Leaf (off + 1)
  | otherwise = let x = div n 2 in
      Branch (balanced off x) (balanced (off + x) (n - x))
