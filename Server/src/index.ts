import { env } from 'process';
import { WebSocketServer, WebSocket, MessageEvent } from 'ws';

const PORT = Number.parseInt(env['PORT'] ?? '8080');
console.log('starting server on port: ', PORT);

const PING_TIMEOUT = 10000;
const ws = new WebSocketServer({ port: PORT });
let host: {
    ws: WebSocket,
    name: string,
} | null = null;

let client: {
    ws: WebSocket,
    name: string
} | null = null;

let connections:Array<{
    ws: WebSocket,
    timeout: NodeJS.Timeout,
}> = [];

const parseWebsocketMessage = (message: MessageEvent) => {
    if (typeof message.data === 'string') return message.data;
    if (typeof message.data === 'object') {
        return new TextDecoder().decode(message.data as ArrayBuffer);
    }
}

type GameState = 'fighting' | 'waiting-for-host' | 'waiting-for-client';

const updateState = (state: GameState, ignore: WebSocket | null = null) => {
    console.log('changed state to ', state);
    connections
        .filter((conn) => conn.ws !== ignore)
        .forEach((conn) => {
            conn.ws.send(JSON.stringify({
                type: 'state-changed',
                data: {
                    state,
                    host: host?.name,
                    client: client?.name
                }
            }));
        });
};

ws.on('connection', (wsclient) => {
    console.log('Someone connected');

    const createTimeout  = () => (
        setTimeout(() => {
            console.log('lost connection to client');
            try {
                wsclient.close();
            } catch { }
            connections = connections.filter((conn) => conn.ws !== wsclient);
        }, PING_TIMEOUT)
    );

    connections.push({
        timeout: createTimeout(),
        ws: wsclient
    });

    let gameState: GameState = 'waiting-for-host';
    if (!host) {
        gameState = 'waiting-for-host';
    } else if (!client) {
        gameState = 'waiting-for-client';
    } else {
        gameState = 'fighting';
    }

    wsclient.send(JSON.stringify({
        type: 'state-changed',
        data: {
            state: gameState,
            host: host?.name,
            client: client?.name
        }
    }));

    wsclient.send(JSON.stringify({
        type: 'ping',
    }));

    wsclient.onmessage = ((event) => {
        const msgAsString = parseWebsocketMessage(event);
        if (!msgAsString) return;
        const parsedMessage = JSON.parse(msgAsString);
        const type = parsedMessage['type'];

        if (type === 'pong') {
            const foundConn = connections.find((conn) => ( conn.ws === wsclient ));
            if (foundConn) {
                clearTimeout(foundConn.timeout);
                foundConn.timeout = createTimeout();
            }
        }

        if (type === 'host') {
            if (host !== null) {
                console.log('error hosting - already a host');
                wsclient.send(JSON.stringify({
                    type: 'host-confirmation',
                    data: false,
                    msg: 'there is already a host'
                }));
                return;
            }

            wsclient.send(JSON.stringify({
                type: 'host-confirmation',
                data: true
            }));

            host = {
                ws: wsclient,
                name: parsedMessage['content']['name']
            };
            updateState('waiting-for-client', wsclient);

            console.log('new host');
            return;
        }


        if (type === 'join') {
            if (host === null){
                console.log('error client - no host found');
                wsclient.send(JSON.stringify({
                    type: 'join-confirmation',
                    data: false,
                    msg: 'no host found'
                }));
                return;
            }

            if (client !== null){
                console.log('error client - already a client');
                wsclient.send(JSON.stringify({
                    type: 'join-confirmation',
                    data: false,
                    msg: 'there is already a client'
                }));
                return;
            }

            wsclient.send(JSON.stringify({
                type: 'join-confirmation',
                data: true
            }));

            client = {
                ws: wsclient,
                name: parsedMessage['content']['name']
            };

            updateState('fighting');
            console.log('new client');
        }

        if (type === 'draw') {
            console.log('draw');
            const outcome = {
                type: 'match-outcome',
                hostWin: false,
                clientWin: false,
            }

            host = null;
            client = null;

            console.log(outcome);

            for (let conn of connections) {
                conn.ws.send(JSON.stringify(outcome));
            }
        }

        if (type === 'win') {
            const outcome = {
                type: 'match-outcome',
                hostWin: false,
                clientWin: false,
            }

            if (wsclient === client?.ws) {
                outcome.clientWin = true;
                // client has won, switch to host
                host = client;
                client = null;
            } else if (wsclient === host?.ws) {
                outcome.hostWin = true;
                // host has won, no need to switch
                // remove client
                client = null;
            } else {
                client = null;
                host = null;
            }

            console.log(outcome);

            for (let conn of connections) {
                conn.ws.send(JSON.stringify(outcome));
            }
        }

        if (type === 'game-sync') {
            console.log(parsedMessage);
            for (let conn of connections) {
                if (conn.ws !== wsclient) {
                    conn.ws.send(
                        JSON.stringify(parsedMessage)
                    );
                }
            }
        }

        wsclient.onerror = () => {
            console.log('error');
        }
        wsclient.onclose = () => {
            console.log('someone disconnected');
            connections = connections.filter((c) => c.ws !== client?.ws);
            if (host?.ws === wsclient) {
                host = null;
                updateState('waiting-for-host');
                return;
            }

            if (client?.ws === wsclient) {
                client = null;
                updateState('waiting-for-client');
            }
        }
    });

    ws.on('close', () => {
        console.log('close 2');
    });

    ws.on('error', () => {
        console.log('error 2');
    });
});
