module GaussElim where

import Control.Monad
import qualified Data.List as List
import M
import Q
import Mat
import Utils

-- | Performs gaussian elimination on a matrix.
gaussElim :: Mat -> M Mat
gaussElim mat = do
  go mat 0
  where
    -- jth column
    go :: Mat -> Int -> M Mat 
    go mat j | j > min (nCols mat - 1) (nRows mat - 1) = do
      assert 
        ("The matrix must be solvable.")
        (isSolvable mat)
      debug 1 "done with gaussElim"
      pure mat
    go mat j | otherwise = do
      debug 1 $ "(nCols mat - 1) = " ++ show (nCols mat - 1)
      debug 1 $ "(nRows mat - 1) = " ++ show (nRows mat - 1)
      debug 1 $ "j = " ++ show j

      assert 
        ("The matrix must be solvable.")
        (isSolvable mat)

      let minCountLeading0s = 
            foldr1 min $
            filter (j <=) $
            countLeading0sRows mat

      debug 1 $ "minCountLeading0s = " ++ show minCountLeading0s
      if j == minCountLeading0s then do
        i <- chooseST
              ("Choosing row as representative for column." )
              (\i -> countLeading0sRow (getRow i mat) == minCountLeading0s)
              [0 .. nRows mat - 1]

        mat <- simplifyRow i j mat
        mat <- eliminateCol i j mat
        go mat (j + 1)
      else do
        debug 1 $ "skipping column " ++ show j
        go mat (j + 1)

-- | Simplifies row i at column j by dividing row i by it's column j entry
simplifyRow :: Int -> Int -> Mat -> M Mat
simplifyRow i j mat = do
  let x = getEntry i j mat 
  assert
    ("Simplify row " ++ show i ++ " at column " ++ show j ++ " by dividing by nonzero entry m[i,j] = " ++ displayQ x)
    (x /= 0)
  pure $ scaleRowMat i (1/x) mat

-- | Eliminates column j from each row, other than row i, by subtracting a multiple of row i equal to the column j entry of the row
eliminateCol :: Int -> Int -> Mat -> M Mat
eliminateCol i j mat = foldM (flip fold) mat (deleteAtList i [0..nRows mat - 1])
  where
    row = getRow i mat
    fold i' = eliminateColRow i' j row

-- | Eliminates column j from row i by subtracting a multiple of the given row equal to the column j entry of the row
eliminateColRow :: Int -> Int -> Row -> Mat -> M Mat
eliminateColRow i j row mat = do
  let x = getEntry i j mat
  pure $ subRowMat i ((x *) <$> row) mat


-- | eliminate denominators
elimDenoms :: Mat -> M Mat
elimDenoms mat = foldM (flip fold) mat [0..nCols mat - 1]
  where
    fold :: Int -> Mat -> M Mat
    fold j mat = do
      -- get lcm, n, of the denomenators of entries in column j of the rows
      let col = getCol j mat
      let dens = denomenatorInt <$> col
      let n = foldr lcm 1 dens
      if n == 1 then
        pure mat
      else do
        -- intro new var, y, that satisfies the eq: xj - n*y = 0
        let row = Row [ if j' == j then
                          1
                        else if j' == (nCols mat - 1) + 1 then 
                          toRational (-n)
                        else
                          0
                      | j' <- [0..(nCols mat - 1) + 1] ] 0
        mat <- pure $ addEmptyCol mat
        mat <- pure $ addRow row mat
        -- gaussian eliminate to propogate new eq
        gaussElim mat -- WARN: may cause infinite loop if variables are solved in a way that keeps producing non-integral coefficients. but i think that inserting the new equation at the top of the new matrix will prevent this