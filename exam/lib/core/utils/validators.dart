class Validators {
  static String? email(String? v){
    if(v==null || v.isEmpty) return 'เธเธฃเธญเธเธญเธตเน€เธกเธฅ';
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
    return ok ? null : 'เธญเธตเน€เธกเธฅเนเธกเนเธ–เธนเธเธ•เนเธญเธ';
  }
  static String? min6(String? v)=> (v==null || v.length<6)?'เธญเธขเนเธฒเธเธเนเธญเธข 6 เธ•เธฑเธงเธญเธฑเธเธฉเธฃ':null;
}
