with Ada.Text_IO, Ada.Integer_Text_IO, Ada.Numerics.Float_Random;
use  Ada.Text_IO, Ada.Integer_Text_IO, Ada.Numerics.Float_Random;

procedure exercise8 is

    Count_Failed    : exception;    -- Exception to be raised when counting fails
    Gen             : Generator;    -- Random number generator

    protected type Transaction_Manager (N : Positive) is
        entry Finished;
        entry Wait_Until_Aborted;
        function Commit return Boolean;
        procedure Signal_Abort;
    private
        Finished_Gate_Open  : Boolean := False;
        Aborted             : Boolean := False;
        Should_Commit       : Boolean := True;
    end Transaction_Manager;
    protected body Transaction_Manager is

        entry Wait_Until_Aborted when Aborted is
        begin
            null;
        end Wait_Until_Aborted;

        entry Finished when Finished_Gate_Open or Finished'Count = N is
        begin
        -- FILL IN PART 3
            Should_Commit := True;
            Finished_Gate_Open := True;
                if Aborted /= False then
                    Should_Commit := False;
                end if;

            if Finished'Count = 0 then
                Finished_Gate_Open := False;
                Aborted := False;
            end if;
        -- END PART 3
        end Finished;

        procedure Signal_Abort is
        begin
            Aborted := True;
        end Signal_Abort;

        function Commit return Boolean is
        begin
            return Should_Commit;
        end Commit;
        
    end Transaction_Manager;



    
    function Unreliable_Slow_Add (x : Integer; Manager : access Transaction_Manager) return Integer is
    Error_Rate : Constant := 0.15;  -- (between 0 and 1)
    begin
    -- FILL IN PART 1
        if (Random(Gen)*1.0) < Error_Rate then
            Manager.Signal_Abort;
        end if;

        select
            Manager.Wait_Until_Aborted;
                Put_Line ("Selected ABORT");
                return x + 5;
        then abort
            delay Duration(4);
            return x + 10;
        end select;

    -- END PART 1
    end Unreliable_Slow_Add;




    task type Transaction_Worker (Initial : Integer; Manager : access Transaction_Manager);
    task body Transaction_Worker is
        Num         : Integer   := 0;
        Prev        : Integer   := Num;
        Round_Num   : Integer   := 0;
    begin
        Put_Line ("Worker" & Integer'Image(Initial) & " started");

        loop
            Put_Line ("Worker" & Integer'Image(Initial) & " started round" & Integer'Image(Round_Num));
            Round_Num := Round_Num + 1;
        -- FILLL IN PART 2.1
            Num := Unreliable_Slow_Add(Num, Manager);
        
            Manager.Finished;

        -- END PART 2.1
            if Manager.Commit = True then
                Put_Line ("  Worker" & Integer'Image(Initial) & " comitting" & Integer'Image(Num));
            else
                Put_Line ("  Worker" & Integer'Image(Initial) &
                             " forwarded from" & Integer'Image(Prev) &
                             " to" & Integer'Image(Num));
            -- FILL IN PART 2.2
            -- FILL IN END.2
            end if;

            Prev := Num;
            delay Duration(0.5);

        end loop;

    end Transaction_Worker;

    Manager : aliased Transaction_Manager (3);

    Worker_1 : Transaction_Worker (0, Manager'Access);
    Worker_2 : Transaction_Worker (1, Manager'Access);
    Worker_3 : Transaction_Worker (2, Manager'Access);

begin
    Reset(Gen); -- Seed the random number generator
end exercise8;



