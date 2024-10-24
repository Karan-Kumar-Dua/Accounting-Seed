@IsTest
public with sharing class LookupQLTest {

    private static String getJson(String field, String op, Object val, string type) {
        Map<String,Object> input = new Map<String,Object>();
        input.put('field', field);
        input.put('op', op);
        input.put('val', val);
        input.put('type', type);
        return JSON.serialize(input);
    }

    @IsTest
    private static void deserializeWhere_OpIsEq() {
        String jsonStr = getJson('test', '=', 5, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = 5';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OpIsNotEq() {
        String jsonStr = getJson('test', '!=', 5, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test != 5';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OpIsGt() {
        String jsonStr = getJson('test', '>', 5, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test > 5';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OpIsGtEq() {
        String jsonStr = getJson('test', '>=', 5, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test >= 5';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OpIsLt() {
        String jsonStr = getJson('test', '<', 5, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test < 5';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OpIsLtEq() {
        String jsonStr = getJson('test', '<=', 5, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test <= 5';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OpIsIn() {
        List<Integer> values = new List<Integer>{ 1, 2, 3 };
        String jsonStr = getJson('test', 'IN', values, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test IN (1, 2, 3)';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OpIsNotIn() {
         List<Integer> values = new List<Integer>{ 1, 2, 3 };
        String jsonStr = getJson('test', 'NOT IN', values, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test NOT IN (1, 2, 3)';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsBoolean() {
        Boolean value = false;
        String jsonStr = getJson('test', '=', value, 'boolean');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = false';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsDate() {
        String value = DateTime.now().format('yyyy-MM-dd');
        String jsonStr = getJson('test', '=', value, 'date');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = ' + value;
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsDateTime() {
        DateTime now = DateTime.now();
        String value = now.format('yyyy-MM-dd HH:mm:ss');
        String jsonStr = getJson('test', '=', value, 'datetime');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = ' + now.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsDecimal() {
        Decimal value = 500.00005;
        String jsonStr = getJson('test', '=', value, 'decimal');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = 500.00005';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsDouble() {
        Double value = 50.00001;
        String jsonStr = getJson('test', '=', value, 'double');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = 50.00001';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsId() {
        Id value = '001xa000003DIloAAG';
        String jsonStr = getJson('test', '=', value, 'id');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = \'001xa000003DIloAAG\'';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsInteger() {
        Integer value = 5;
        String jsonStr = getJson('test', '=', value, 'integer');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = 5';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsLong() {
        Long value = 5000000;
        String jsonStr = getJson('test', '=', value, 'long');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = 5000000';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_DataTypeIsString() {
        String jsonStr = getJson('test', '=', 'value', 'string');
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE test = \'value\'';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_SimpleExpr() {
        String jsonStr = '{ "field":"Name", "op":"=", "val":"Test", "type":"string" }';
        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE Name = \'Test\'';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_OrExpr() {
        String jsonStr = 
            '{ "or": [' + 
                '{ "field":"Name", "op":"=", "val":"Test", "type":"string" }, ' +
                '{ "field":"BillingStreet", "op":"=", "val":"123 Seasame", "type":"string" }' +
            ']}';

        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE (Name = \'Test\' OR BillingStreet = \'123 Seasame\')';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_AndExpr() {
        String jsonStr = 
            '{ "and": [' + 
                '{ "field":"Name", "op":"=", "val":"Test", "type":"string" }, ' +
                '{ "field":"BillingStreet", "op":"=", "val":"123 Seasame", "type":"string" }' +
            ']}';

        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE (Name = \'Test\' AND BillingStreet = \'123 Seasame\')';
        System.assertEquals(expectedResult, result);
    }

    @IsTest
    private static void deserializeWhere_NestedExpr() {
        String jsonStr = 
            '{ "and": [' + 
                '{ "field":"Name", "op":"=", "val":"Seasame Test", "type":"string" }, ' +
                '{"or": [' +
                    '{ "field":"BillingStreet", "op":"=", "val":"123 Seasame", "type":"string" }, ' +
                    '{ "field":"BillingStreet", "op":"=", "val":"321 Seasame", "type":"string" }' +
                ']}'+   
            ']}';

        String result = LookupQL.deserializeWhere(jsonStr);

        String expectedResult = 'WHERE (Name = \'Seasame Test\' AND (BillingStreet = \'123 Seasame\' OR BillingStreet = \'321 Seasame\'))';
        System.assertEquals(expectedResult, result);
    }

     @IsTest
    private static void deserializeWhere_NullInput() {
        String jsonStr = null;
        String result = LookupQL.deserializeWhere(jsonStr);
        System.assertEquals('', result);
    }

    @IsTest
    private static void deserializeWhere_BlankInput() {
        String jsonStr = '';
        String result = LookupQL.deserializeWhere(jsonStr);
        System.assertEquals('', result);
    }

    @IsTest
    private static void deserializeWhere_EmptyObjInput() {
        String jsonStr = '{}';
        String result = LookupQL.deserializeWhere(jsonStr);
        System.assertEquals('', result);
    }

    @IsTest
    private static void deserializeWhere_InvalidJson() {
        String jsonStr = '{ "field":"Name", "op":"=", "val":"Test", "type":"String" ';
        Exception expectedEx;
        try {
            String result = LookupQL.deserializeWhere(jsonStr);
        } catch(LookupQL.InvalidJsonQueryFormatException ex) {
           expectedEx = ex;
        }
        System.assertNotEquals(null, expectedEx);
    }

    @IsTest
    private static void deserializeWhere_InvalidComparisonOp() {
        String jsonStr = '{ "field":"Name", "op":"*", "val":"Test", "type":"String" }';
        Exception expectedEx;
        try {
            String result = LookupQL.deserializeWhere(jsonStr);
        } catch(LookupQL.InvalidJsonQueryFormatException ex) {
           expectedEx = ex;
        }
        System.assertNotEquals(null, expectedEx);
    }

    @IsTest
    private static void deserializeWhere_InvalidDataType() {
        String jsonStr = '{ "field":"Name", "op":"=", "val":"Test", "type":"test" }';
        Exception expectedEx;
        try {
            String result = LookupQL.deserializeWhere(jsonStr);
        } catch(LookupQL.InvalidJsonQueryFormatException ex) {
           expectedEx = ex;
        }
        System.assertNotEquals(null, expectedEx);
    }

}