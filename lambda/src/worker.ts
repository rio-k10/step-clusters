export const handler = async (event: any) => {
  console.log("Worker invoked with:", JSON.stringify(event));
  return { ok: true, note: "Worker finished console log." };
};
