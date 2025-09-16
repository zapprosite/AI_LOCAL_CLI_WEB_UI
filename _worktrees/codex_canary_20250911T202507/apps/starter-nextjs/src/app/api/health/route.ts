export const runtime = 'nodejs';
export async function GET() {
  return new Response(JSON.stringify({ status: 'ok', time: new Date().toISOString() }), {
    headers: { 'content-type': 'application/json' }
  });
}
