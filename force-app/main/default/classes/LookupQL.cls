public with sharing class LookupQL {

    private static final Set<String> COMPARISON_OPERATOR_WHITELIST = new Set<String> { 
        '=',
        '!=',
        '<',
        '<=',
        '>',
        '>=',
        'IN',
        'NOT IN'
    };

    private static final Set<String> DATA_TYPE_WHITELIST = new Set<String> { 
        'boolean',
        'date',
        'datetime',
        'decimal',
        'double',
        'id',
        'integer',
        'long',
        'string'
    };

    public class InvalidJsonQueryFormatException extends Exception {}

    public static String deserializeWhere(String jsonString) {
        String whereClause = '';
        try {
            if (String.isNotBlank(jsonString)) {
                Map<String,Object> expr = (Map<String,Object>) JSON.deserializeUntyped(jsonString);
                if (expr.size() > 0) {
                    whereClause = 'WHERE ' + deserializeWhereHelper(expr);
                }
            }
        } catch(InvalidJsonQueryFormatException ex) {
            throw ex;
        } catch(Exception ex) {
            throw new InvalidJsonQueryFormatException(ex.getMessage());
        }
        return whereClause;
    }

    private static String deserializeWhereHelper(Map<String,Object> expr) {
        if (expr.containsKey('or')) {
            return reduceLogicalExpr((List<Object>) expr.get('or'), ' OR ');
        } else if (expr.containsKey('and')) {
            return reduceLogicalExpr((List<Object>) expr.get('and'), ' AND ');
        } else if (expr.containsKey('field') && expr.containsKey('op') && expr.containsKey('val') && expr.containsKey('type')) {            
            return getBaseExpr(expr);
        } else {
            throw new InvalidJsonQueryFormatException();
        }
    }

    private static String reduceLogicalExpr(List<Object> expr, String joinStr) {
        List<String> resultParts = new List<String>();
        for (Object part : expr) {
            Map<String,Object> typeCastPart = (Map<String,Object>) part;
            resultParts.add(deserializeWhereHelper(typeCastPart));
        }
        String result = String.join(resultParts, joinStr);
        return '(' + result + ')';
    }

    private static String getBaseExpr(Map<String,Object> expr) {
        String type = (String) expr.get('type');
        String op = (String) expr.get('op');
        Object val = expr.get('val');
        String field = String.escapeSingleQuotes((String) expr.get('field'));
        if (!validOp(op) || !validType(type)) {
            throw new InvalidJsonQueryFormatException();
        }
        return (field + ' ' + op + ' ' + convert(val, type, op));
    }

    private static Boolean validOp(String op) {
        return COMPARISON_OPERATOR_WHITELIST.contains(op.toUpperCase());
    }

    private static Boolean validType(String t) {
        return DATA_TYPE_WHITELIST.contains(t.toLowerCase());
    }

    private static Object convert(Object val, String type, String op) {
        Object obj;
        if (op == 'IN' || op == 'NOT IN') {
            obj = convertList(val, type);
        } else {
            obj = convert(val, type);
        }
        return obj;
    }

     private static List<Object> convertList(Object val, String type) {
        List<Object> objs = new List<Object>();
        List<Object> vals = (List<Object>) val;
        for (Object obj : vals) {
            objs.add(convert(obj, type));
        }
        return objs;
    }

    private static Object convert(Object val, String type) {
        switch on type.toLowerCase() {
            when 'boolean' {	
                return (Boolean) val;
            } when 'date' {	
                Date d = Date.valueOf((String) val);
                return Datetime.newInstance(d.year(), d.month(), d.day()).format('yyyy-MM-dd');
            } when 'datetime' {		
                return Datetime.valueOf((String) val).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            } when 'decimal' {
                return (Decimal) val;
            } when 'double' {
                return (Double) val;
            } when 'id' {
                Id s = (Id) String.escapeSingleQuotes((String) val);
                return '\'' + s + '\'';
            } when 'integer' {
                return (Integer) val;
            } when 'long' {
                return (Long) val;
            } when 'string' {
                String s = (String) String.escapeSingleQuotes((String) val);
                return '\'' + s + '\'';
            }
        }
        return null;
    }

}