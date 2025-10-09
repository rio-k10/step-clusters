import { SFNClient, StartExecutionCommand } from "@aws-sdk/client-sfn";

const sfn = new SFNClient({});

export const handler = async (event: any) => {
  console.log("Ingress received event:", JSON.stringify(event));

  const stateMachineArn = process.env.STATE_MACHINE_ARN;
  if (!stateMachineArn) {
    console.error("STATE_MACHINE_ARN not set");
    return { statusCode: 500, body: "Misconfigured lambda" };
  }

  const name = `exec-${Date.now()}`;
  const input = JSON.stringify({ from: "ingress", payload: event });

  await sfn.send(new StartExecutionCommand({ stateMachineArn, name, input }));

  return { statusCode: 202, body: JSON.stringify({ ok: true, started: name }) };
};
