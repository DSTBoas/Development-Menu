local Threading = {}

function Threading:StartThread(id, fn, valid, onStopped)
    return StartThread(function()

        while valid() do
            fn()
        end

        if onStopped then
            onStopped()
        end

        KillThreadsWithID(id)
    end, id)
end

function Threading:StopThread(id)
    KillThreadsWithID(id)
end

return Threading
