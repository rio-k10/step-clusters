import { SQSHandler, SQSBatchItemFailure, SQSEvent } from 'aws-lambda';
import { SFNClient, StartExecutionCommand } from '@aws-sdk/client-sfn';
import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';

const sfn = new SFNClient({});
const STATE_MACHINE_ARN = process.env.STATE_MACHINE_ARN;

type Inbound = {
  type: string;
  correlationId?: string;
  payload?: unknown;
  ts?: string;
};

export const handler: SQSHandler = async (event: SQSEvent) => {
  if (!STATE_MACHINE_ARN) {
    console.error('STATE_MACHINE_ARN not set');
    return {
      batchItemFailures: event.Records.map((r) => ({
        itemIdentifier: r.messageId
      }))
    };
  }

  const failures: SQSBatchItemFailure[] = [];

  await Promise.all(
    event.Records.map(async (r) => {
      try {
        const body = JSON.parse(r.body) as Inbound;
        if (!body.type) throw new Error('missing type');

        const name = (body.correlationId ?? r.messageId)
          .replace(/[^A-Za-z0-9-_]/g, '_')
          .slice(0, 80);

        await sfn.send(
          new StartExecutionCommand({
            stateMachineArn: STATE_MACHINE_ARN,
            name,
            input: JSON.stringify(body)
          })
        );
      } catch (err) {
        console.error('consumer_error', { messageId: r.messageId, err });
        failures.push({ itemIdentifier: r.messageId });
      }
    })
  );

  return { batchItemFailures: failures };
};
