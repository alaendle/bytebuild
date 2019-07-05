{-# language BangPatterns #-}
{-# language ScopedTypeVariables #-}
{-# language TypeApplications #-}

import Control.Monad.ST (runST)
import Data.Bytes.Types (MutableBytes(..))
import Data.ByteArray.Builder.Small
import Data.Word
import Data.Char (ord)
import Data.Primitive (ByteArray)
import Debug.Trace
import Test.Tasty (defaultMain,testGroup,TestTree)
import Test.QuickCheck ((===))
import Text.Printf (printf)
import qualified Data.ByteString.Builder as BB
import qualified Data.Primitive as PM
import qualified Data.List as L
import qualified Data.Vector as V
import qualified Test.Tasty.QuickCheck as TQC
import qualified Test.QuickCheck as QC
import qualified GHC.Exts as Exts
import qualified Data.ByteString.Lazy.Char8 as LB

import qualified HexWord64

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests"
  [ testGroup "live"
    [ TQC.testProperty "word64Dec" $ \w ->
        run 1 (word64Dec w) === pack (show w)
    , TQC.testProperty "word64Dec-x3" $ \x y z ->
        run 1 (word64Dec x <> word64Dec y <> word64Dec z)
        ===
        pack (show x ++ show y ++ show z)
    , TQC.testProperty "int64Dec-x3" $ \x y z ->
        run 1 (int64Dec x <> int64Dec y <> int64Dec z)
        ===
        pack (show x ++ show y ++ show z)
    , TQC.testProperty "word64BE-x3" $ \x y z ->
        run 1 (word64BE x <> word64BE y <> word64BE z)
        ===
        pack (LB.unpack (BB.toLazyByteString (BB.word64BE x <> BB.word64BE y <> BB.word64BE z)))
    , TQC.testProperty "word64PaddedUpperHex" $ \w ->
        run 1 (word64PaddedUpperHex w)
        ===
        pack (showWord64PaddedUpperHex w)
    , TQC.testProperty "pasteArrayST" $ \(xs :: [Word64]) ->
        (runArray word64Dec (V.fromList xs))
        ===
        pack (foldMap show xs)
    ]
  , testGroup "alternate"
    [ TQC.testProperty "HexWord64" $ \x y ->
        run 1
          (  fromUnsafe (HexWord64.word64PaddedUpperHex x)
          <> fromUnsafe (HexWord64.word64PaddedUpperHex y)
          )
        ===
        pack (showWord64PaddedUpperHex x <> showWord64PaddedUpperHex y)
    ]
  ]

pack :: String -> ByteArray
pack = Exts.fromList . map (fromIntegral @Int @Word8 . ord)

-- This is used to test pasteArrayST
runArray ::
     (a -> Builder) -- ^ Builder
  -> V.Vector a -- ^ Elements to serialize
  -> ByteArray -- ^ Number of elements serialized, serialization
runArray f !xs = runST $ do
  let go !v0 !sz !chunks = if V.null v0
        then pure (mconcat (L.reverse chunks))
        else do
          arr <- PM.newByteArray sz
          (v1,MutableBytes _ off _) <- pasteArrayST (MutableBytes arr 0 sz) f v0
          -- If nothing was serialized, we need a bigger buffer
          let szNext = if V.length v0 == V.length v1 then sz + 1 else sz
          c <- PM.unsafeFreezeByteArray =<< PM.resizeMutableByteArray arr off
          go v1 szNext (c : chunks)
  go xs 1 []

showWord64PaddedUpperHex :: Word64 -> String
showWord64PaddedUpperHex = printf "%016X" 
