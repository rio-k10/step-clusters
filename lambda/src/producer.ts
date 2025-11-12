import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from "aws-lambda";
import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const sqs = new SQSClient({});
const QUEUE_URL = process.env.QUEUE_URL;

export const handler = async (
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> => {
  if (!QUEUE_URL) {
    console.error("QUEUE_URL not set");
    return { statusCode: 500, body: "Misconfigured lambda" };
  }
  if (!event.body) {
    return { statusCode: 400, body: "Missing body" };
  }

  // Accepts { type, correlationId?, payload }
  const parsed = JSON.parse(event.body);
  if (!parsed?.type) {
    return { statusCode: 422, body: "Field 'type' is required" };
  }

  const correlationId =
    parsed.correlationId ??
    (globalThis.crypto?.randomUUID
      ? globalThis.crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2)}`);

  const messageBody = JSON.stringify({
    type: parsed.type,
    correlationId,
    payload: parsed.payload ?? null,
    ts: new Date().toISOString(),
  });

  await sqs.send(
    new SendMessageCommand({
      QueueUrl: QUEUE_URL,
      MessageBody: messageBody,
    })
  );

  return {
    statusCode: 202,
    body: JSON.stringify({ ok: true, enqueued: true, correlationId }),
    headers: { "content-type": "application/json" },
  };
};
