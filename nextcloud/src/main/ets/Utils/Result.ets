interface ResultOk<T> {
    kind: 'ok';
    data: T;
}

export function Ok<T>(data: T): ResultOk<T> {
    return {
        kind: 'ok',
        data: data,
    };
}

interface ResultError<E> {
    kind: 'error';
    error: E;
}

export function Err<E>(error: E): ResultError<E> {
    return {
        kind: 'error',
        error: error,
    };
}

export type Result<T, E> = ResultOk<T> | ResultError<E>;
