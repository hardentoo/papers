{-# LANGUAGE     BangPatterns, NoMonomorphismRestriction #-}
module Example where
import qualified Generic as G
import qualified Chunked as C


fsInput   = ["input/file1",   "input/file2",   "input/file3",   "input/file4"]
fsOutput  = ["output/file1",  "output/file2",  "output/file3",  "output/file4"]
fsOutputA = ["output/file1a", "output/file2a", "output/file3a", "output/file4a"]
fsOutputB = ["output/file1b", "output/file2b", "output/file3b", "output/file4b"]


example_copySetP :: [FilePath] -> [FilePath] -> IO ()
example_copySetP srcs dsts
 = do  ss <- G.sourceFs srcs
       sk <- G.sinkFs  dsts
       G.drainP ss sk


example_copyMultipleP :: [FilePath] -> [FilePath] -> [FilePath] -> IO ()
example_copyMultipleP srcs dsts1 dsts2
 = do  ss  <- G.sourceFs srcs
       sk1 <- G.sinkFs   dsts1
       sk2 <- G.sinkFs   dsts2 
       G.drainP ss (G.dup_ooo sk1 sk2)


-- Check that the drainFatten rule is well typed.
rule_drainFatten :: G.Range i => G.Sources i IO a -> G.Sinks () IO a -> IO ()
rule_drainFatten s k
 = do   G.funnel_i s >>= \s' -> G.drainP s' k
        G.funnel_o k >>= \k' -> G.drainP s  k'


-- | Example concatenating several input files.
--   We use the fact that funnel_i handles the input streams one after the other.
example_funnel_i :: IO ()
example_funnel_i
 = do   ss      <- G.sourceFs fsInput
        s       <- G.funnel_i ss

        k       <- G.sinkFs    ["output/merged"]
        let k'  =  G.project_o  0 k

        G.drainP s k'


-- Example which fuses across chunks.

-- Compile with the following options to get GHC to fuse this example.
--   -O2 -fsimplifier-phases=5 \
--       -fno-liberate-case \
--       -funfolding-use-threshold1000 -funfolding-keeness-factor1000
--
-- Observe the core code with
--   ghc --make Example.hs -O2 \
--       -fsimplifier-phases=5 -fno-liberate-case \
--       -funfolding-use-threshold1000 -funfolding-keeness-factor1000 \
--       -dverbose-core2core -ddump-prep -dsuppress-all -dppr-case-as-let -dppr-cols200 \
--       > dump.prep
example_map_map :: C.Sources Int IO Int -> C.Sinks Int IO Int -> IO ()
example_map_map ss kk
        = C.drainP (C.map_i (+ 100) (C.map_i (* 200) ss)) kk