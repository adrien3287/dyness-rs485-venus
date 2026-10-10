import sys, pathlib, unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from energy import time_estimates

class TestEnergy(unittest.TestCase):
    def test_discharge_above_ess_floor(self):
        tte,ttf,src = time_estimates(66,53, -200, 100, 35)
        self.assertEqual(src,'battery-discharge')
        self.assertEqual(tte, round((66-5)/100*200*53/200*3600))
        self.assertIsNone(ttf)
    def test_idle_uses_ac_load(self):
        tte,_,src = time_estimates(66,53, 0, 100, 35)
        self.assertEqual(src,'ac-load-fallback')
        self.assertEqual(tte, round(0.61*200*53/110*3600))
    def test_below_ess_min_still_predicts(self):
        tte,_,src = time_estimates(30,53,-150,100,35)
        self.assertGreater(tte,0)
        self.assertEqual(src,'ac-load-fallback')
    def test_no_load(self):
        tte,_,src = time_estimates(66,53,0,10,35)
        self.assertIsNone(tte)
    def test_stop_at_5(self):
        tte,_,_ = time_estimates(4,53,-200,100,35)
        self.assertEqual(tte,0)
    def test_charging_to_95(self):
        _,ttf,_ = time_estimates(66,53,300,100,35)
        self.assertEqual(ttf,round((95-66)/100*200*53/300*3600))
    def test_full_95(self):
        _,ttf,_ = time_estimates(96,53,300,100,35)
        self.assertEqual(ttf,0)
    def test_settings_missing(self):
        self.assertEqual(time_estimates(66,53,-200,100,None)[0],None)

if __name__=='__main__': unittest.main()
