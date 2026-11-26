package main
import("bytes";"crypto/sha256";"testing")
func TestVerifiedDownloadPrefix(t *testing.T){
 for _,n:=range []int{0,1,3,4,33,32769,65536}{
  payload:=bytes.Repeat([]byte{0,1,2,3},(n+3)/4)[:n];sum:=sha256.Sum256(payload)
  if !verifyDownloadPrefix(int64(n),sum[:]){t.Fatalf("valid prefix %d rejected",n)}
  bad:=sum;bad[0]^=1;if verifyDownloadPrefix(int64(n),bad[:]){t.Fatalf("corrupt prefix %d accepted",n)}
 }
 if verifyDownloadPrefix(-1,nil)||verifyDownloadPrefix(1<<30+1,nil){t.Fatal("invalid bounds accepted")}
}
