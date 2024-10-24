@IsTest
public class VirtualCardBlockReturnResultTest {

    static testMethod void testParse() {
        String json = '{'+
                '  \"correlationId\": \"a6c1957f-efcd-4dd8-9e47-65d0a1376c6f\",'+
                '  \"result\": {'+
                '    \"errorType\": \"BAD_REQUEST\",'+
                '    \"description\": {'+
                '      \"error\": \"Error blocking card 3982449, error: Card is not eligible to return funds.\"'+
                '    }'+
                '  }'+
                '}';
        VirtualCardBlockReturnResult obj = VirtualCardBlockReturnResult.parse(json);
        System.assert(obj != null);
    }
}