@isTest
private class FinancialReportFormulaValidatorTest {

  private static FinancialReportFormulaValidator.FormulaTypes rowType;
  private static FinancialReportFormulaValidator.FormulaTypes colType;

  @isTest
  static void testNullRowString() {
    setup();
    validateFilter(null, rowType, 1, 1, false);
  }

  @isTest
  static void testNullColString() {
    setup();
    validateFilter(null, colType, 1, 1, false);
  }

  @isTest
  static void testInvalidRowCharacters() {
    setup();
    validateFilter('{r1} $ {r2}', rowType, 3, 3, false);
    validateFilter('{c1} + {r2}', rowType, 3, 3, false);
  }

  @isTest
  static void testInvalidColCharacters() {
    setup();
    validateFilter('{c1} $ {c2}', colType, 3, 3, false);
    validateFilter('{c1} + {r2}', colType, 3, 3, false);
  }

  @isTest
  static void testValidSimpleRowFormulas() {
    setup();
    validateFilter('{r1} + {r2}', rowType, 3, 3, true);
    validateFilter('{r1} / {r2}', rowType, 3, 3, true);
    validateFilter('{r1} * {r2}', rowType, 3, 3, true);
    validateFilter('{r1} - {r2}', rowType, 3, 3, true);
    validateFilter('{r1} + {r2} + {r3}', rowType, 4, 4, true);
  }

  @isTest
  static void testValidSpacingVariantFormulas() {
    setup();
    validateFilter('{r1}+{r2}', rowType, 3, 3, true);
    validateFilter('{r1} + {r2}-{r3}', rowType, 4, 4, true);
    validateFilter('{r1} + {r2}    -{r3}      ', rowType, 4, 4, true);
  }

  @isTest
  static void testInvalidSpacingVariantFormulas() {
    setup();
    validateFilter('{r1}+{r 2}', rowType, 3, 3, false);
    validateFilter('{r1} + {r2}-{r 3}', rowType, 4, 4, false);
  }

  @isTest
  static void testInvalidSimpleRowFormulas() {
    setup();
    validateFilter('{r1} + {r7}', rowType, 3, 3, false);
    validateFilter('{r1} + {r2} +', rowType, 3, 3, false);
    validateFilter('+ {r1} + {r2}', rowType, 3, 3, false);
    validateFilter('{r1} {r2}', rowType, 3, 3, false);
    validateFilter('{r0} + {r1}', rowType, 3, 3, false);
  }

  @isTest
  static void testValidSimpleColFormulas() {
    setup();
    validateFilter('{c1} + {c2}', colType, 3, 3, true);
    validateFilter('{c1} / {c2}', colType, 3, 3, true);
    validateFilter('{c1} * {c2}', colType, 3, 3, true);
    validateFilter('{c1} - {c2}', colType, 3, 3, true);
    validateFilter('{c1} + {c2} + {c3}', colType, 4, 4, true);
  }

  @isTest
  static void testInvalidSimpleColFormulas() {
    setup();
    validateFilter('{c1} + {c7}', colType, 3, 3, false);
    validateFilter('{c1} + {c2} +', colType, 3, 3, false);
    validateFilter('+ {c1} + {c2}', colType, 3, 3, false);
    validateFilter('{c1} {c2}', colType, 3, 3, false);
    validateFilter('{c0} + {c1}', colType, 3, 3, false);
  }

  @isTest
  static void testValidRowParenFormulas() {
    setup();
    validateFilter('({r1} + {r2})', rowType, 3, 3, true);
    validateFilter('({r1} * ({r2} / {r3}))', rowType, 4, 4, true);
    validateFilter('({r1} * {r2}) / ({r3} * {r4})', rowType, 5, 5, true);
  }

  @isTest
  static void testValidColParenFormulas() {
    setup();
    validateFilter('({c1} + {c2})', colType, 3, 3, true);
    validateFilter('({c1} * ({c2} / {c3}))', colType, 4, 4, true);
    validateFilter('({c1} * {c2}) / ({c3} * {c4})', colType, 5, 5, true);
  }

  @isTest
  static void testInvalidRowRanges() {
    setup();
    validateFilter('{r1:r5}', rowType, 3, 3, false);
    validateFilter('{r1:r4}', rowType, 4, 4, false);
    validateFilter('{r3:r1}', rowType, 4, 4, false);
    validateFilter('{r1:c2}', rowType, 3, 3, false);
  }

  @isTest
  static void testValidRowRanges() {
    setup();
    validateFilter('{r1:r2}', rowType, 3, 3, true);
    validateFilter('{r1:r3}', rowType, 4, 4, true);
  }

  // private setup method
  private static void setup() {
    rowType = FinancialReportFormulaValidator.FormulaTypes.ROW;
    colType = FinancialReportFormulaValidator.FormulaTypes.COL;
  }

  // test assertion utility
  private static void validateFilter(String exp, FinancialReportFormulaValidator.FormulaTypes type, Integer currentRowCol, Integer rowColCount, Boolean valid) {

    FinancialReportFormulaValidator f = new FinancialReportFormulaValidator(exp, type, currentRowCol, rowColCount);
    FinancialReportFormulaValidator.ValidationResult res = f.validate();

    String msg = exp + ' should ' + ((valid) ? '' : 'not ') + 'be valid';

    if (res.errors != null && res.errors.size() > 0) {
      for (FinancialReportFormulaValidator.ValidationResultError vr : res.errors) {
        msg += ' || [' + vr.location + '] ' + vr.message;
      }
    }

    System.assertEquals(valid, res.valid, msg);
  }

  private class ExpressionTestException extends Exception {}

}