/*
*
* CalculationEngine Class
* Author:	Kevin O'Hara
* Created:	02-10-2011
* Version:	1.0
*
*/
public with sharing class CalculationEngine {

	public Decimal calculate(String incalc) {
		
		String calcstring = incalc.trim().replaceAll(' ', '');
		Decimal value = 0;
		Boolean foundvalue;	
		
		String p = '\\(([^\\(\\)]*?)\\)';
		
		Pattern patt = Pattern.compile(p);
		Matcher matcher = patt.matcher(calcstring);
		
		foundvalue = matcher.find();
		
		if(foundvalue) {
			
			do {
    			String replacement = matcher.group(1).replaceAll('\\+', '\\\\+').replaceAll('\\*', '\\\\*');
    			String calculatedsubstring = String.valueOf(getCalc(matcher.group(1)));
    			calcstring = calcstring.replaceAll('\\(' + replacement + '\\)', calculatedsubstring);
    			matcher = patt.matcher(calcstring);
    			foundvalue = matcher.find();
    			
			} while (foundvalue);
			
			
		}
		
		return getCalc(calcstring);
		
	}
	
	private Decimal getCalc(String s) {
		
		Decimal value = 0;
		
		String incalcstring = s;
		String outcalcstring;
		
		incalcstring = incalcstring.replaceAll('\\+', '\\@\\+\\@');
		incalcstring = incalcstring.replaceAll('\\*', '\\@\\*\\@');
		incalcstring = incalcstring.replaceAll('\\-', '\\@\\-\\@');
		incalcstring = incalcstring.replaceAll('\\/', '\\@\\/\\@');
		incalcstring = incalcstring.replaceAll('\\@\\@', '\\@');
		
		String[] tokens = incalcstring.trim().split('@');
		
		for(Integer i = 0; i<tokens.size(); i++) {
			
			if(tokens[i] != null && tokens[i] != '') {
				
				if (i==0 && (tokens[i] != '+' && tokens[i] != '-' && tokens[i] != '/' && tokens[i] != '*' )) {
					value = Decimal.valueOf(tokens[i]);
					tokens[i] = null;
				} else if (tokens[i] == '+') {
					if(tokens[i+1] == '-') {
						value = value + Decimal.valueOf(tokens[i+1] + tokens[i+2]);
						tokens[i] = null;
						tokens[i+1] = null;
						tokens[i+2] = null;
					} else {
						value = value + Decimal.valueOf(tokens[i+1]);
						tokens[i] = null;
						tokens[i+1] = null;
					}
				} else if (tokens[i] == '-') {
					if(tokens[i+1] == '-') {
						value = value - Decimal.valueOf(tokens[i+1] + tokens[i+2]);
						tokens[i] = null;
						tokens[i+1] = null;
						tokens[i+2] = null;
					} else {
						value = value - Decimal.valueOf(tokens[i+1]);
						tokens[i] = null;
						tokens[i+1] = null;
					}
				} else if (tokens[i] == '*') {
					if(tokens[i+1] == '-') {
						value = value * Decimal.valueOf(tokens[i+1] + tokens[i+2]);
						tokens[i] = null;
						tokens[i+1] = null;
						tokens[i+2] = null;
					} else {
						value = value * Decimal.valueOf(tokens[i+1]);
						tokens[i] = null;
						tokens[i+1] = null;
					}
				} else if (tokens[i] == '/') {
					if(tokens[i+1] == '-') {
						value = value / Decimal.valueOf(tokens[i+1] + tokens[i+2]);
						tokens[i] = null;
						tokens[i+1] = null;
						tokens[i+2] = null;
					} else {
						value = value / Decimal.valueOf(tokens[i+1]);
						tokens[i] = null;
						tokens[i+1] = null;
					}
				}
			}
			
		}	
		
		return value;
	}

}