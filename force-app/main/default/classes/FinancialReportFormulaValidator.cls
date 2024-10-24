public with sharing class FinancialReportFormulaValidator {

  private String formulaString;
  private FormulaTypes formulaType;
  private Integer currentRowCol;
  private Integer totalRowCols;

  private Pattern valuePattern;
  private Pattern rangePattern;

  public List<FormulaSymbol> symbolList;

  private static final Pattern INT_PATTERN = Pattern.compile('^[0-9]+$');

  private static final Set<String> validOperators = new Set<String> { '+', '-', '/', '*' };

  public FinancialReportFormulaValidator(String formulaString, FormulaTypes formulaType, Integer currentRowCol, Integer totalRowCols) {
    this.formulaString = (formulaString != null) ? formulaString.toUpperCase() : null;
    this.formulaType = formulaType;
    this.currentRowCol = currentRowCol;
    this.totalRowCols = totalRowCols;

    String valueToken;
    if (this.formulaType == FormulaTypes.ROW) {
      valueToken = 'R';
    }
    else {
      valueToken = 'C';
    }

    String digits = String.valueOf(String.valueOf(totalRowCols).length());

    String valuePatternString = '^\\{' + valueToken + '([0-9]{1,' + digits + '})\\}$';
    String rangePatternString = '^\\{' + valueToken + '([0-9]{1,' + digits + '})\\:' + valueToken + '([0-9]{1,' + digits + '})\\}$';

    this.valuePattern = Pattern.compile(valuePatternString);
    this.rangePattern = Pattern.compile(rangePatternString);
  }

  public void parse() {
    this.symbolList = new List<FormulaSymbol>();

    FormulaSymbol sol = new FormulaSymbol();
    sol.type = SymbolTypes.SOL;
    sol.location = -1;
    sol.value = '';
    this.symbolList.add(sol);

    List<String> chars = new List<String>();

    // split to all characters
    if (this.formulaString != null) {
      chars = this.formulaString.toUpperCase().split('');
      //In API version 34.0 and earlier, a zero-width regExp value produces an empty list item at the beginning of the method’s output.
      //chars.remove(0);

      for (Integer i = 0; i < chars.size(); i++) {
        FormulaSymbol es = new FormulaSymbol();
        es.location = i;
        es.valid = true;

        if (chars[i] == ' ' || chars[i] == null) continue;

        if (chars[i] == '(') {
          es.type = SymbolTypes.OPEN_PAREN;
          es.value = '(';
          symbolList.add(es);
          continue;
        }

        if (chars[i] == ')') {
          es.type = SymbolTypes.CLOSED_PAREN;
          es.value = ')';
          symbolList.add(es);
          continue;
        }

        es.value = chars[i];

        if (es.value == '{') {
          es.type = SymbolTypes.VALUE;
        }

        while (true) {
          // reached EOL
          if ((i + 1) >= chars.size()) break;

          // break on whitespace
          if (chars[i + 1] == ' ') break;

          // break on parens
          if (chars[i + 1] == '(' || chars[i + 1] == ')') break;

          if (chars[i + 1] == '{') break;

          i++;

          // if there is a : when processing the value, it's actually
          // a range and we'll switch the type to SYMBOLTYPES.RANGE
          if (chars[i] == ':' && es.type == SymbolTypes.VALUE) {
            es.type = SymbolTypes.RANGE;
          }

          es.value += chars[i];

          // break on end of range or value
          if (chars[i] == '}') {
            break;
          }
        }

        // Matcher m = INT_PATTERN.matcher(es.value);

        if (es.type == null) {
          es.type = SymbolTypes.OPERATOR;
        }

        symbolList.add(es);
      }
    }

    FormulaSymbol eol = new FormulaSymbol();
    eol.type = SymbolTypes.EOL;
    eol.location = chars.size();
    eol.value = '';
    this.symbolList.add(eol);

  }

  public ValidationResult validate() {
    this.parse();

    ValidationResult res = new ValidationResult();
    res.symbolList = this.symbolList;

    Integer openParenCount = 0;
    Integer closedParenCount = 0;
    Integer operatorCount = 0;

    String label = (this.formulaType == FormulaTypes.ROW) ? 'row' : 'column';

    // iterate over all but the first (SOL)
    for (Integer i = 1; i < this.symbolList.size(); i++) {
      if (res.valid == false) break;

      FormulaSymbol thisSymbol = this.symbolList.get(i);
      SymbolTypes prevSymbolType = this.symbolList.get(i - 1).type;

      ////////////////////////
      // validate value types
      ////////////////////////

      if (thisSymbol.type == SymbolTypes.VALUE) {

        Matcher valueMatcher = valuePattern.matcher(thisSymbol.value);

        if (!valueMatcher.matches()) {
          res.addError('Invalid ' + label + ' value ' + thisSymbol.value + ' at position ' + thisSymbol.location, thisSymbol.location);
          continue;
        }

        Integer rowColNum = Integer.valueOf(valueMatcher.group(1));

        // make sure the row/column number doesn't exceed the total number of rows/columns
        if (rowColNum == 0 || rowColNum >= this.totalRowCols || rowColNum >= this.currentRowCol) {
          res.addError('Invalid ' + label + ' value: ' + thisSymbol.value, thisSymbol.location);
          continue;
        }

        if (prevSymbolType != SymbolTypes.OPERATOR
            && prevSymbolType != SymbolTypes.SOL
            && prevSymbolType != SymbolTypes.OPEN_PAREN) {
          res.addError('Invalid filter ' + thisSymbol.value + ' at position ' + thisSymbol.location, thisSymbol.location);
          continue;
        }
      }

      ////////////////////////
      // validate range types
      ////////////////////////

      else
        if (thisSymbol.type == SymbolTypes.RANGE) {

          Matcher rangeMatcher = rangePattern.matcher(thisSymbol.value);
          String invalidRange = String.format(System.Label.ERR_INVALID_RANGE, new List<Object>{label});

          if (!rangeMatcher.matches()) {
            res.addError(invalidRange + ': ' + thisSymbol.value, thisSymbol.location);
            continue;
          }

          Integer rowColNum1 = Integer.valueOf(rangeMatcher.group(1));
          Integer rowColNum2 = Integer.valueOf(rangeMatcher.group(2));

          // make sure the row/column number doesn't exceed the total number of rows/columns
          if (rowColNum1 == 0 || rowColNum2 == 0 || rowColNum1 > this.totalRowCols || rowColNum2 > this.totalRowCols) {
            res.addError(invalidRange + ': ' + thisSymbol.value, thisSymbol.location);
            continue;
          }

          if (rowColNum1 == this.currentRowCol || rowColNum2 == this.currentRowCol) {
            res.addError(System.Label.ERR_FORMULA_CANNOT_REFERENCE_ITSELF + ': ' + thisSymbol.value, thisSymbol.location);
            continue;
          }

          if (rowColNum1 > rowColNum2) {
            res.addError(System.Label.ERR_LEFT_VALUE_LESS_THAN_RIGHT + ': ' + thisSymbol.value, thisSymbol.location);
            continue;
          }

          if (prevSymbolType != SymbolTypes.OPERATOR
              && prevSymbolType != SymbolTypes.SOL
              && prevSymbolType != SymbolTypes.OPEN_PAREN) {
            String invalidFilter = String.format(System.Label.ERR_INVALID_FILTER, new List<Object>{thisSymbol.value});
            res.addError(invalidFilter + ' ' + thisSymbol.location, thisSymbol.location);
            continue;
          }
        }

        //////////////////////////
        // validate operator types
        //////////////////////////

        else
          if (thisSymbol.type == SymbolTypes.OPERATOR) {

            if (!validOperators.contains(thisSymbol.value)) {
              res.addError(System.Label.ERR_INVALID_OPERATOR_AT_POSITION + ' ' + thisSymbol.location + ': ' + thisSymbol.value, thisSymbol.location);
              continue;
            }

            if (prevSymbolType != SymbolTypes.VALUE && prevSymbolType != SymbolTypes.RANGE
                && prevSymbolType != SymbolTypes.CLOSED_PAREN) {
              res.addError(System.Label.ERR_UNEXPECTED_TOKEN_AT_POSITION + ' ' + thisSymbol.location + ': ' + thisSymbol.value, thisSymbol.location);
              continue;
            }

            operatorCount++;
          }

          //////////////////////////
          // valid open paren
          //////////////////////////

          else
            if (thisSymbol.type == SymbolTypes.OPEN_PAREN) {
              openParenCount++;
              if (prevSymbolType != SymbolTypes.OPEN_PAREN
                  && prevSymbolType != SymbolTypes.OPERATOR
                  && prevSymbolType != SymbolTypes.SOL) {
                res.addError(System.Label.ERR_UNEXPECTED_TOKEN_AT_POSITION + ' ' + thisSymbol.location + ': ' + thisSymbol.value, thisSymbol.location);
                continue;
              }

            }

            //////////////////////////
            // valid closed paren
            //////////////////////////

            else
              if (thisSymbol.type == SymbolTypes.CLOSED_PAREN) {
                closedParenCount++;
                if (prevSymbolType != SymbolTypes.VALUE && prevSymbolType != SymbolTypes.RANGE
                    && prevSymbolType != SymbolTypes.CLOSED_PAREN) {
                  res.addError(System.Label.ERR_UNEXPECTED_TOKEN_AT_POSITION + ' ' + thisSymbol.location + ': ' + thisSymbol.value, thisSymbol.location);
                  continue;
                }

              }

              //////////////////////////
              // valid eol
              //////////////////////////

              else
                if (thisSymbol.type == SymbolTypes.EOL) {

                  if (prevSymbolType != SymbolTypes.VALUE && prevSymbolType != SymbolTypes.RANGE
                      && prevSymbolType != SymbolTypes.CLOSED_PAREN) {
                    res.addError(System.Label.ERR_UNEXPECTED_TOKEN_AT_POSITION + ' ' + thisSymbol.location + ': ' + thisSymbol.value, thisSymbol.location);
                    continue;
                  }

                }

    }

    if (res.valid == false) return res;

    /////////////////////////////
    // matching open/close parens
    /////////////////////////////

    if (closedParenCount != openParenCount) {
      res.addError(System.Label.ERR_UNEQUAL_NO_OF_PARANTHESIS, -1);
      return res;
    }

    return res;
  }

  public with sharing class ValidationResult {
    public Boolean valid;
    public List<ValidationResultError> errors;
    public List<FormulaSymbol> symbolList;
    public ValidationResult() {
      this.errors = new List<ValidationResultError>();
      this.symbolList = new List<FormulaSymbol>();
      this.valid = true;
    }
    public void addError(String message, Integer location) {
      this.errors.add(new ValidationResultError(message, location));
      this.valid = false;
    }
  }

  public with sharing class ValidationResultError {
    public Integer location;
    public String message;
    public ValidationResultError(String message, Integer location) {
      this.message = message;
      this.location = location;
    }
  }

  public with sharing class FormulaSymbol {
    public Boolean valid;
    public SymbolTypes type;
    public String value;
    public Integer location;
    public FormulaSymbol() {
      this.valid = true;
    }
  }

  public enum FormulaTypes { ROW, COL }
  public enum SymbolTypes { SOL, EOL, OPERATOR, OPEN_PAREN, CLOSED_PAREN, VALUE, RANGE }

}