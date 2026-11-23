package fcn

import (
	"bytes"
	"testing"
)

func TestAccountProfiles(t *testing.T) {
	id := "1ed909de-848b-41e7-943f-0f2d49b35f3a"
	a, k, e := AccountCredentials(id)
	if e != nil || a != id || len(k) != 32 {
		t.Fatal("invalid credential derivation")
	}
	_, other, _ := AccountCredentials("2ed909de-848b-41e7-943f-0f2d49b35f3a")
	if bytes.Equal(k, other) {
		t.Fatal("credential collision")
	}
	for _, bad := range []string{"", id[:35], "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"} {
		if _, _, e := AccountCredentials(bad); e == nil {
			t.Fatal("accepted invalid UUID")
		}
	}
	for _, v := range []int{1, 2} {
		c, e := AccountConfig(v, "localhost:443", "localhost", id)
		if e != nil || c.validate() != nil {
			t.Fatal(e)
		}
		if (v == 1 && c.QUICLanes != 1) || (v == 2 && (!c.RecoveryAware || !c.AdaptiveLanes || c.QUICLanes != 2)) {
			t.Fatal("profile drift")
		}
	}
	if _, e := AccountConfig(3, "localhost:443", "localhost", id); e == nil {
		t.Fatal("accepted unknown profile")
	}
}
