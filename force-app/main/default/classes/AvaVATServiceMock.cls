@IsTest
public with sharing class AvaVATServiceMock implements Callable  {
    public static Map<String,Integer> calls = new Map<String,Integer>();

    private void incCalls(String action) {
        if (AvaVATServiceMock.calls.containsKey(action)) {
            AvaVATServiceMock.calls.put(action, (AvaVATServiceMock.calls.get(action) + 1));
        } else {
            AvaVATServiceMock.calls.put(action, 1);
        }
    }
    
    public AvaVATServiceMock() {
        AvaVATServiceMock.calls.clear();
    }

    public static Integer timesCalled(String action) {
        return AvaVATServiceMock.calls.containsKey(action) ? AvaVATServiceMock.calls.get(action) : 0;
    }

    public Object call(String action, Map<String, Object> args) {
        Object result;
        
        if (!args.containsKey('authKey')) {
            throw new AvaVATServiceMockException('Expected arg "authKey"');
        }

        switch on action {
            when 'submitBillingsToAvaVAT' {
                if (!args.containsKey('billingIds')) {
                    throw new AvaVATServiceMockException('Expected arg "billingIds"');
                }

                if (!args.containsKey('postAction')) {
                    throw new AvaVATServiceMockException('Expected arg "postAction"');
                }

                if (args.containsKey('postAction') && (args.get('postAction') != 'POST' && args.get('postAction') != 'UNPOST')) {
                    throw new AvaVATServiceMockException('Expected arg "postAction" is either "POST" or "UNPOST"');
                }
            }
            when 'submitPayablesToAvaVAT' {
                if (!args.containsKey('payableIds')) {
                    throw new AvaVATServiceMockException('Expected arg "payableIds"');
                }

                if (!args.containsKey('postAction')) {
                    throw new AvaVATServiceMockException('Expected arg "postAction"');
                }

                if (args.containsKey('postAction') && (args.get('postAction') != 'POST' && args.get('postAction') != 'UNPOST')) {
                    throw new AvaVATServiceMockException('Expected arg "postAction" is either "POST" or "UNPOST"');
                }
            }
            when 'validateAvaVATLedgerSettings' {
                if (!args.containsKey('ledgers')) {
                    throw new AvaVATServiceMockException('Expected arg "ledgers"');
                }
            }
            when 'validateVATCountryReportable' {
                if (!args.containsKey('invLines')) {
                    throw new AvaVATServiceMockException('Expected arg "invLines"');
                }
            }
            when else {
                throw new AvaVATServiceMockException('Method not implemented');
            }
        }

        incCalls(action);
        return result;
    }

    public with sharing class AvaVATServiceMockException extends Exception {}

}