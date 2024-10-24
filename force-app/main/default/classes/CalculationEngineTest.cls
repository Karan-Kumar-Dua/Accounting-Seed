@IsTest
public class CalculationEngineTest {

    @IsTest
    static void testCalcEngine() {
        CalculationEngine engine = new CalculationEngine();

        Decimal test1 = engine.calculate('( 2 + 8 ) - 4');
        System.assertEquals(6, test1);

        Decimal test2 = engine.calculate('(12/3) - 4');
        System.assertEquals(0, test2);

        Decimal test3 = engine.calculate('(5*8 ) - (4/2)');
        System.assertEquals(38, test3);

        Decimal test4 = engine.calculate('(-5*8 ) - (4/2)');
        System.assertEquals(-42, test4);

        Decimal test5 = engine.calculate('(-5*-8 )');
        System.assertEquals(40, test5);

        Decimal test6 = engine.calculate('(-5--8 )');
        System.assertEquals(3, test6);

        Decimal test7 = engine.calculate('(-5/-8 )');
        System.assertEquals(0.625, test7);

        Decimal test8 = engine.calculate('(-5+-8 )');
        System.assertEquals(-13, test8);

        Decimal test9 = engine.calculate('-9 * 55');
        System.assertEquals(-495, test9);
    }

}