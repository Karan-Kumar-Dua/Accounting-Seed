public class YodleeBDCRouter extends AbstractBDCRouter{
  public override AbstractBDCConnector getConnectorClass(){
    return new YodleeBDCConnector();
  }
    
  public override AbstractBDCConverter getConvertorClass(){
    return new YodleeBDCConverter();
  }

  public override AbstractBDCTransactionBulk getTransacationBulkProcessorClass(){
    return new YodleeBDCTransactionBulk();
  }
}