program RPN;
  {$CODEPAGE UTF-8}

  {----------------------------------}
  {     О структуре комментариев     }
  {Все подпрограммы разбиты на блоки }
  {исходя из того, для чего они      }
  {были созданы. Но это не исключает }
  {их дальнейшего использования в    }
  {подпрограммах других блоков.      }
  {Здесь и далее начало блока будет  }
  {обрамляться "***", конец "@@@@",  }
  {а примечания с                    }
  {помощью знаков "---"              }
  {----------------------------------}

  const NUM_OF_OP = 8;                //Максимальное число операторов в таблице операторов
        MAX_LENGTH_OF_OPERATOR = 2;   //Максимальная длина оператора                      
        MAX_VARIABLE_NAME_LENGTH = 5; //Максимальная длина имени переменной               
        AMOUNT_OF_NUMERALS = 10;      //Количество цифр в таблице цифр                    

  type  t_max_str_op = string[MAX_LENGTH_OF_OPERATOR];                       //Строка оператора. Устанавливается длина для уменьшения занимаемой памяти
        t_array_of_op = array [1 .. NUM_OF_OP] of t_max_str_op;              //Массив строк операторов                                                 
        t_array_of_op_pri = array [1 .. NUM_OF_OP] of byte;                  //Массив приоритетов операторов                                           
        t_array_of_numerals_chars = array [1 .. AMOUNT_OF_NUMERALS] of char; //Символы цифр, используемых в вычислениях                                

        t_p_complex = ^t_complex;       //Указатель на комплексное число           
        t_p_node = ^t_node;             //Указатель на узел стека или списка   
        t_p_cell = ^t_cell;             //Указатель на ячейку вычисл. выражения
        t_p_variable = ^t_variable;     //Указатель на переменную              
        t_p_max_str_op = ^t_max_str_op; //Указатель на строку оператора        
        t_p_string = ^string;           //Указатель на строку                  

        t_complex = record {Комплексное число}
                      re : real;
                      im : real; 
                    end;

        t_node = record {Узел стека или списка}
                   data : pointer;  //Указатель на данные, хранящиеся в узле
                   link : t_p_node; // Указатель на следующий узел
                 end;
          
        t_stack = record {Стек. Содержит только указатель на вершину}
                    head : t_p_node;
                  end;

        t_list = record {Список. Содержит только указатель на начало}
                   start : t_p_node;
                 end;
        
        t_operators_table =  record {Таблица операторов}
                               op_s : t_array_of_op;     // Строковые представления операторов
                               op_p : t_array_of_op_pri; // Приоритеты операторов
                             end;

        t_RPN_expression = record {Выражение в ОПЗ}
                              expres : string; // Строковое представление выражения
                              st : t_stack;    // Стек для преобразования выражения, содержащий операторы
                           end;
        
        t_cell = record {Ячейка вычисляемого выражения}
                   type_c : string[3];  // Тип ячейки
                   data : pointer;      // Указатель на данные в ячейке
                 end;

        t_variable = record  {Переменная выражения}
                       name : string[MAX_VARIABLE_NAME_LENGTH]; //Имя переменной
                       value : pointer;                         //Указатель на значение переменной
                     end;

        t_calculated_RPN_expression = record  {Вычисляемое выражение в ОПЗ}
                                        expres : t_list;    // Список ячеек выражения. Каждая ячейка - оператор или операнд 
                                        variables : t_list; // Список переменных выражения
                                        st : t_stack;       // Стек для вычислений
                                        inter_res : t_list; // Список промежуточных итогов вычислений
                                      end;
        
  const OPERATORS : t_operators_table = (op_s : ('(', ')', '-', '~', '+', '*', '/', 'ln'); op_p : (1, 1, 2, 4, 2, 3, 3, 5));
        NUMERALS : t_array_of_numerals_chars = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9');

  {----------------------------------}
  {     Про таблицу операторов       }
  {             OPERATORS            }
  {Оператарами условно названо все,  }
  {что не является операндом. Sin, ln}
  {и т.п называются операторами.     }
  {При изменении таблицы операторов  }
  {учтите, что если оператор имеет   }
  {и унарную, и бинарную функцию,    }
  {как, например, минус, то вы должны}
  {расположить отдельный символ для  }
  {обозначения унарной операции сразу}
  {после бинарной в табл. операторов }
  {----------------------------------}

  {----------------------------------}
  {        Про таблицу цифр          }
  {            NUMERALS              }
  {Она составлена на случай того,    }
  {если понадобится использовать     }
  {систему счисления, отличную от 10й}
  {Изменение таблицы на данный момент}
  {повлияет лишь на то, какой тип    }
  {будет присвоен ячейке вычисляемого}
  {выражения на этапе преобразования }
  {строки ОПЗ в вычисл. выражение.   }
  {Определять операции над числами   }
  {и т.п. в другой СС                }
  {необходимо самостоятельно         }
  {----------------------------------}

  {**********************************}
  {Базовые операции над структурами  }
  {**********************************}

  {* Присваивает строковому представлению выражения в ОПЗ expres пустую строку, а указателю вершины стека - nil}
  procedure create_expression(var expres : t_RPN_expression); 
    begin
      expres.expres := '';
      expres.st.head := nil;
    end;

  {* Присваивает указателю начала списка ячеек, списка переменных, списка промежуточных итогов
   * и указателю вершины стека вычисляемого выражения в ОПЗ expres значение nil}
  procedure create_calculated_express(var expres : t_calculated_RPN_expression);
    begin
      expres.expres.start := nil;
      expres.variables.start := nil;
      expres.st.head := nil;
      expres.inter_res.start := nil;
    end;

  {* Добавляет указатель pt на вершину стека stack}
  procedure push(var stack : t_stack; var pt : pointer);
    var p_node : t_p_node; 
    begin
      new(p_node); 
      p_node^.link := stack.head;
      p_node^.data := pt;
      stack.head := p_node;
    end;

  {* Присваивает указателю pt указатель, хранящийся на вершине стека, удаляя его из стека}
  procedure pop(var stack : t_stack; var pt : pointer);
    var t : t_p_node;
    begin
      t := stack.head;
      pt := stack.head^.data;
      stack.head := t^.link;
      dispose(t);
    end;

  {* Присваивает указателю p_node указатель на начало списка list}
  procedure link_node_list_start(const list : t_list; var p_node : t_p_node);
    begin
      p_node := list.start;
    end;

  {* Добавляет указатель pt в конец списка list, как элемент списка }
  procedure push_last(var list : t_list; var pt : pointer);
    var p_node, p_nd_list : t_p_node;
    begin
      new(p_node);
      p_node^.data := pt;
      p_node^.link := nil;

      if list.start = nil then
        list.start := p_node
      else
        begin
          link_node_list_start(list, p_nd_list);
          while p_nd_list^.link <> nil do
            p_nd_list := p_nd_list^.link;
          p_nd_list^.link := p_node;
        end;
    end;
  
  {* Присваивает указателю pt указатель элемента, хранящейся в начале списка list, удаляя его списка}
  procedure pop_first(var list : t_list; var pt : pointer);
    var p_nd_list : t_p_node;
    begin
      p_nd_list := list.start;
      list.start := list.start^.link;
      pt := p_nd_list^.data;
      dispose(p_nd_list);
    end;

  {* Очищает память, занимаемую узлами списка list, а так же блоки памяти размера  n байт, на которые указывают указатели, хранящиеся в каждом узле. 
   * Будьте осторожны: данная процедура не сможет полностью очистить память, если указатели узлов указывают на блоки памяти разной длины, 
   * или они указывают на блоки памяти, которые занимают структуры, имеющие свои указатели на динамические переменные}
  procedure clear_list(var list : t_list; const n : byte);
    var p : pointer;
    begin
      while list.start <> nil do
        begin
          pop_first(list, p);
          freeMem(p, n);
        end;
    end;

  {* Присваивает указателю p_element указатель, хранящийся в узле p_node. 
   * p_node, обязанный быть узлом списка или стека, начинает указывать на следующий узел.
   * Будьте осторожны: подпрограмма не отслеживает ситуации, когда p_node указывает на nil.
   * Если вы попробуете получить элемент за границей стека или списка - произойдет ошибка времени выполнения}
  procedure take_implicitly_element(var p_node : t_p_node; var p_element : pointer);
    begin
      p_element := p_node^.data;
      p_node := p_node^.link;
    end;

  {* Присваивает указателю p_elemnt указатель, хранящийся в узле списка list с номером n. Указатель из списка НЕ удаляется
   * Будьте осторожны: если вы укажите n больше, чем количество узлов списка - произойдет ошибка времени выполнения}
  procedure take_list_element_by_num(const list : t_list; const n : byte; var p_element : pointer);
    var i : byte;
        p_node : t_p_node;
    begin
      i := 1;
      p_node := list.start; 
      while i < n do
        begin
          p_node := p_node^.link;
          i += 1;
        end;
      p_element := p_node^.data;
    end;

  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}
  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}

  {**********************************}
  {ПОДПРОГРАММЫ ПРЕОБРАЗОВАНИЯ В ОПЗ }
  {**********************************}

  {* Возвращает номер строкового представления оператора opr из таблицы операторов OPERATORS.
   * Если opr не является строковым представлением оператора - функция возвращает значение 0}
  function num_of_operator(const opr : string) : byte;
    var i : byte;
    begin
      i := 1;
      while (i <= NUM_OF_OP) and (opr <> OPERATORS.op_s[i]) do 
        i += 1;
      if i > NUM_OF_OP then
        i := 0;
      num_of_operator := i;
    end;

  {* Возвращает слово, считанное с индекса i в строке s,
   * пропуская предшествующие пустые символы и присваивая параметру i
   * номер символа после считанного слова. Если нет слова - возвращает пустую строку}
  function get_word(const s : string; var i : byte) : string;
    var part : string;
        len : byte;
    begin
      len := length(s); 	    
      while (s[i] <= ' ') and (i <= len) do
        i += 1;
      part := '';
      while (s[i] > ' ') and (i <= len) do
        begin
          part := part + s[i];
          i := i + 1;
        end;
      get_word := part; 
    end;

  {* Возвращает значение "истина", если символ ch является частью таблицы чисел NUMERALS.
   * Иначе - возвращает значение "ложь"}
  function char_is_part_of_num_table(const ch : char) : boolean;
    var i : byte;
    begin
      i := 1;
      while (i < AMOUNT_OF_NUMERALS) and (NUMERALS[i] <> ch) do
        i += 1;
      char_is_part_of_num_table := ch = NUMERALS[i];
    end;

  {* Возвращает значение "истина", если первый символ строки str
   * является частью таблицы чисел NUMERALS. Иначе - возвращает значение "ложь"}
  function is_const(const str : string) : boolean;
    begin
      is_const := char_is_part_of_num_table(str[1]); 
    end;
 
  {* Возвращает значение "истина", если приоритет оператора а больше или равен приоритету оператора b.
   * Иначе - возвращает значение "ложь"}
  function priority_comp(const a, b : byte) : boolean;
    begin
      priority_comp := OPERATORS.op_p[a] >= OPERATORS.op_p[b];
    end;
  
  {Возвращает значение разыменованного указателя p_opr. Указатель p_opr должен указывать на строковое представление оператора}
  function get_operator(const p_opr : t_p_max_str_op) : t_max_str_op;
    begin
      get_operator := p_opr^;
    end;
  
  {* Пока приоритет оператора с номером op_n из таблицы операторов OPERATORS больше или равен
   * приоритету оператора на вершине стека выражения expres - оператор с вершины стека удаляется
   * и добавляется в строкове представление выражения expres}
  procedure pop_operators(var expres : t_RPN_expression; const op_n : byte);
    var p_opr : t_p_max_str_op;
        p_head : t_p_node;
    begin
      p_opr := expres.st.head^.data;
      p_head := expres.st.head;
      while (p_head <> nil) and (priority_comp(num_of_operator(p_opr^), op_n)) do
        begin
          expres.expres := expres.expres + p_opr^ + ' ';
          expres.st.head := p_head^.link;
          dispose(p_head);
          p_head := expres.st.head;
          if p_head <> nil then
              p_opr := expres.st.head^.data;
        end;
    end;
  
  {* Пока в стеке выражения expres не встретится закрывающая скобка "(" - 
   * операторы будут удаляться с вершины стека и добавляться
   * в строковое представление выражения expres. 
   * Закрывающая скобка будет удалена из стека, но не добавлена в строкове представление}
  procedure end_bracket_pushing(var expres : t_RPN_expression);
    var pt : t_p_max_str_op;
    begin
      while get_operator(expres.st.head^.data) <> '(' do
        begin
          pop(expres.st, pt);
          expres.expres := expres.expres + pt^ + ' ';
        end;
      pop(expres.st, pt);
    end;

  {* Добавляет к номеру оператора op_n единицу, если он имеет
   * бинарную форму в таблице операторов OPERATORS}
  procedure binary_to_unary(var op_n : byte);
    begin
      case OPERATORS.op_s[op_n] of
        '-' : op_n += 1;
      end;
    end;

  {* Обновляет стек операторов и строкове представление выражения expres по правилам ОПЗ в зависимости от того,
   * является ли оператор с номером op_n в таблице операторов OPERATORS унарным (определяется значением параметр is_un. Унарный - "истина", иначе - "ложь"),
   * и какое строковое представление имеет}
  procedure update_expression_operators(var expres : t_RPN_expression; var op_n : byte; const is_un : boolean);
    var p : t_p_max_str_op;
    begin
      if is_un then
        binary_to_unary(op_n);
      p := @OPERATORS.op_s[op_n];
      case p^ of
        '(' : push(expres.st, p);
        ')' : end_bracket_pushing(expres); 
        else
          begin
            if expres.st.head <> nil then
              pop_operators(expres, op_n);
            push(expres.st, p);
          end;
      end;
    end;

  {* Удаляет все операторы из стека операторов выражения expres, 
   * добавляя их в строковое представление}
  procedure pop_stack_of_expres(var expres : t_RPN_expression);
    var p_opr : t_p_max_str_op;
    begin
      while expres.st.head <> nil do
        begin
          pop(expres.st, p_opr);
          expres.expres := expres.expres + p_opr^ + ' ';
        end;
    end;

  {* Возвращает строку, которая является записью строки s, содержащей математическое выражение,
   * по правилам ОПЗ}
  function trans_expression_to_RPN(const s : string) : string;
    var part : string;
        i, num_op : byte; 
        expres : t_RPN_expression;
        is_un : boolean;
    begin
      create_expression(expres);
      i := 1;
      is_un := True;
      part := get_word(s, i);
      while part <> '' do
        begin
          num_op := num_of_operator(part);
          if num_op = 0 then
            expres.expres := expres.expres + part + ' '
          else
            update_expression_operators(expres, num_op, is_un);
          is_un := num_op <> 0;
          part := get_word(s, i);
        end;
      pop_stack_of_expres(expres); 
      trans_expression_to_RPN := expres.expres;
    end;

  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}
  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}

  {**********************************}
  {Подпрограммы создания на основе   }
  {строки с выражением, записанным   }
  {в ОПЗ, вычисляемого выражения     }
  {**********************************}

  {* Возвращает имя переменной, указатель на которую хранится в узле p_node}
  function take_variable_name_from_node(const p_node : t_p_node) : string;
    var p_var : t_p_variable;
    begin
      p_var := p_node^.data;
      take_variable_name_from_node := p_var^.name
    end;

  {* Возвращает значение "истина", если переменная с именем name входит в список list, присваивая параметру i её номер в списке.
   * Иначе - возвращает значение "ложь"}
  function is_variable_in_list(const list : t_list; const name : string; var i : byte) : boolean;
    var p_nd_list : t_p_node;
    begin
      link_node_list_start(list, p_nd_list);
      i := 1;
      while (p_nd_list <> nil) and (take_variable_name_from_node(p_nd_list) <> name) do
        begin
          i += 1;
          p_nd_list := p_nd_list^.link;
        end;
      is_variable_in_list := p_nd_list <> nil;
    end;

  {* Возвращает количество слов в строке s}
  function count_words(const s : string) : byte;
    var i, n : byte;
    begin
      n := 0;
      i := 1;
      while get_word(s, i) <> '' do
        n += 1;
      count_words := n;
    end;

  {* Возвращает строку, являющуюся действительной частью комплексного числа, записанного в строку complex_str;
   * параметру i присваивается номер символа после действительной части.
   * Если действительной части нет - возвращает строку '0', параметру i присваивается значение 1}
  function take_real_part(const complex_str : string; var i : byte) : string;
    var len : byte;
        res : string;
    begin
      len := length(complex_str);
      res := '';
      while (i <= len) and (complex_str[i] <> '+') and (complex_str[i] <> '-') do
        begin
          res := res + complex_str[i];
          i += 1;
        end;
      if complex_str[i - 1] = 'i' then
        begin
          i := 1;
          res := '0';
        end;
      take_real_part := res;
    end;

    {* Возвращает строку, являющуюся мнимой частью комплексного числа, записанного в строку complex_str;
     * параметру i присваивается номер символа, где находится мнимая единица.
     * Если мнимой части нет - возвращает строку 0}
    function take_imaginary_part(const complex_str : string; var i : byte) : string;
      var len : byte;
          res : string;
      begin
        len := length(complex_str);
        res := '';
        while i < len do
          begin
            res := res + complex_str[i];
            i += 1;
          end;
        if res = '' then
          res := '0';
        take_imaginary_part := res; 
      end;

  {* Присваивает комплексному числу, хранящемуся по указателю p_complex значение комплексного числа из строки complex_str}
  procedure construct_complex(var p_complex : t_p_complex; const complex_str : string);
    var i, code : byte;
        number : string;
    begin
      i := 1;
      number := take_real_part(complex_str, i);
      val(number, p_complex^.re, code);
      number := take_imaginary_part(complex_str, i);
      val(number, p_complex^.im, code);
    end;

  {* Создает переменную с именем name и записывает указатель на неё в ячейку по указателю p_cell}
  procedure form_var_cell(var p_cell : t_p_cell; const name : string);
    var p_var : t_p_variable;
    begin
      new(p_var);
      p_var^.name := name;
      p_cell^.data := p_var;
    end;

  {* Создает комплексное число из строки complex_str и записывает указатель на него в ячейку по указателю p_cell}
  procedure form_con_cell(var p_cell : t_p_cell; const complex_str : string);
    var p_complex : t_p_complex;
    begin
      new(p_complex);
      construct_complex(p_complex, complex_str);
      p_cell^.data := p_complex;
    end;

  {* Записывает в ячейку по указателю p_cell адрес оператора со строковым представлением opr_s в таблице операторов OPERATORS}
  procedure form_opr_cell(var p_cell : t_p_cell; const opr_s : string);
    begin
      p_cell^.data := @OPERATORS.op_s[num_of_operator(opr_s)];
    end;

  {* Записывает в ячейку по указателю p_cell указатель переменную, константу или оператор с данными из строки data,
   * если тип ячейки по указателю p_cell равен var, con или opr соответственно }
  procedure create_data_cell(var p_cell : t_p_cell; const data : string);
    begin
      case p_cell^.type_c of
        'var' : form_var_cell(p_cell, data);
        'con' : form_con_cell(p_cell, data);
        'opr' : form_opr_cell(p_cell, data);
      end;
    end;

  {* Возвращает строку с типом ячейки, в которой будут храниться данные из строки data,
   * как var, con или opr, если data - это имя переменной, константа или оператор соответственно}
  function cell_type(const data : string) : string;
    var num_opr : byte;
        type_of_cell : string;
    begin
      num_opr := num_of_operator(data);
      if num_opr = 0 then
        begin
          if is_const(data) then 
            type_of_cell := 'con'
          else
            type_of_cell := 'var';
        end
      else
        type_of_cell := 'opr';
      cell_type := type_of_cell;
    end;

  {* Присваивает указателю значения переменной по указателю p_variable указатель на значение переменной по указателю p_var_main}
  procedure add_link_to_variable(const p_var_main : t_p_variable; var p_variable : t_p_variable);
    begin
      p_variable^.value := p_var_main^.value;
    end;

  {* Создает переменную по указателю p_variable_main, присваивая её указателю на значение указатель на комплексное в динамической памяти.
   * Указателю на значение переменной по указателю p_variable так же присваивается указатель на это комплексное.
   * Переменной по указателю p_variable_name присваивается имя переменной по указателю p_variable}
  procedure create_variable_main (var p_variable, p_variable_main : t_p_variable);
    var p_complex : t_p_complex;
    begin
      new(p_variable_main);
      new(p_complex);
      p_variable_main^.value := p_complex;
      p_variable^.value := p_variable_main^.value;
      p_variable_main^.name := p_variable^.name;
    end;

  {* Обновляет список переменных list_of_var, добавляя в него указатель на переменную p_variable, или
   * если переменная с таким же именем, как у переменной по указателю p_variable, уже имеется в списке - 
   * то указателю на значение переменной по указателю p_variable присваивается указатель на значение переменной с таким же именем,
   * которая уже есть в списке list_of_var}
  procedure update_list_of_variables(var list_of_var : t_list; var p_variable : t_p_variable);
    var i : byte;
        p_var_main : t_p_variable;
    begin
      if is_variable_in_list(list_of_var, p_variable^.name, i) then
        begin
          take_list_element_by_num(list_of_var, i, p_var_main);
          add_link_to_variable(p_var_main, p_variable);
        end
      else
        begin
          create_variable_main(p_variable, p_var_main);
          push_last(list_of_var, p_var_main);
        end;
    end;

  {* Преобразует строку expres_s, в которой содержится выражение, записанное в ОПЗ, в вычисляемое выражение
   * и записывает его в вычисляемое выражение expres_calc}
  procedure string_into_calculated(const expres_s : string; var expres_calc : t_calculated_RPN_expression);
    var part : string;
        cell : t_p_cell;
        j, i : byte;
    begin
      create_calculated_express(expres_calc);
      j := 1;
      for i := 1 to count_words(expres_s) do
        begin
          part := get_word(expres_s, j);
          new(cell);
          cell^.type_c := cell_type(part);
          create_data_cell(cell, part);
          push_last(expres_calc.expres, cell);
          if cell^.type_c = 'var' then
            update_list_of_variables(expres_calc.variables, cell^.data);
        end; 
    end;
  
  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}
  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}

  {**********************************}
  {Подпрограммы вычисления значения  }
  {вычисляемого выражения           }
  {**********************************}

  {* Читает значения переменных вычисляемого выражения expres, вводимые пользователем}
  procedure read_variables(var expres : t_calculated_RPN_expression);
    var data : string;
        p_node : t_p_node;
        p_var : t_p_variable;
        p_complex : t_p_complex;
    begin
      link_node_list_start(expres.variables, p_node);
      repeat
        take_implicitly_element(p_node, p_var);
        write('Введите значение переменной ', p_var^.name, ': ');
        readln(data);
        p_complex := p_var^.value;
        construct_complex(p_complex, data);
      until p_node = nil;
    end;

  {* Присваивает по указателю p_res результат сложения комплексных чисел по указателям p_comp1 и p_comp2}
  procedure addition(var p_comp1, p_comp2, p_res : t_p_complex);
    begin
      p_res^.re := p_comp1^.re + p_comp2^.re;
      p_res^.im := p_comp1^.im + p_comp2^.im;
    end; 

  {* Присваивает по указателю p_res результат вычитания комплексных чисел по указателям p_comp1 и p_comp2}
  procedure subtraction(var p_comp1, p_comp2, p_res : t_p_complex);
    begin
      p_res^.re := p_comp2^.re - p_comp1^.re;
      p_res^.im := p_comp2^.im - p_comp1^.im;
    end;

  {* Присваивает по указателю p_res результат умножения комплексных чисел по указателям p_comp1 и p_comp2}
  procedure multiplication(var p_comp1, p_comp2, p_res : t_p_complex);
    begin
      p_res^.re := p_comp1^.re * p_comp2^.re - p_comp1^.im * p_comp2^.im;
      p_res^.im := p_comp1^.re * p_comp2^.im + p_comp1^.im * p_comp2^.re;
    end;

  {* Присваивает по указателю p_res результат деления комплексных чисел по указателям p_comp1 и p_comp2}
  procedure division(var p_comp1, p_comp2, p_res : t_p_complex);
    begin
      p_res^.re := (p_comp2^.re * p_comp1^.re + p_comp2^.im * p_comp1^.im) / (sqr(p_comp1^.re) + sqr(p_comp1^.im));
      p_res^.im := (p_comp1^.re * p_comp2^.im - p_comp2^.re * p_comp1^.im) / (sqr(p_comp1^.re) + sqr(p_comp1^.im));
    end;

  {* Присваивает по указателю p_res результат преминения унарного минуса к комплексному числу по указателю p_comp}
  procedure unary_minus(var p_comp, p_res : t_p_complex);
    begin
      p_res^.re := -p_comp^.re;
      p_res^.im := -p_comp^.im;
    end;

  {* Присваивает по указателю p_res результат вычисления натурального логарифма комплексного числа по указателю p_comp}
  procedure natural_logarithm(var p_comp, p_res : t_p_complex);
    begin
      p_res^.re := ln(sqrt(sqr(p_comp^.re) + sqr(p_comp^.im)));
      p_res^.im := arctan(p_comp^.im / p_comp^.re);
    end;

  {* Если оператор по указателю p бинарный - то по указателям p1 и p2 присваиваются указатели из стека st,
   * которые удаляются из самого стека. 
   * Если оператор унарный - то из стека удаляется только один указатель и присваивается указателю p1}
  procedure take_operands(var st : t_stack; var p1, p2 : pointer; const p : t_p_string);
    begin
      if (p^ = '+') or (p^ = '-') or (p^ = '*') or (p^ = '/') then
        begin
          pop(st, p1);
          pop(st, p2);
        end
      else
        pop(st, p1);
    end;

  {* Возвращает символ "+" если число num больше или равно 0, иначе - возвращает символ "-"}
  function sign_of_number(const num : real) : string;
    var sign : string;
    begin
      if num >= 0 then
        sign := '+'
      else
        sign := '-';
      sign_of_number := sign;
    end;

  {* Возвращает строковое представление комплексного числа по указателю p_complex }
  function complex_to_string(const p_complex : t_p_complex) : string;
    var a, b, sign : string;
    begin
      sign := sign_of_number(p_complex^.im);
      p_complex^.im := abs(p_complex^.im);
      str(p_complex^.re : 0 : 2, a);
      str(p_complex^.im : 0 : 2, b);
      complex_to_string := a + sign + b + 'i';
    end;

  {* Выводит на экран пронумерованные промежуточные результаты вычислений вычисляемого выражения,
   * которые записаны в список list_of_inter_res}
  procedure print_inter_results(var list_of_inter_res : t_list);
    var p_nd_list : t_p_node;
        i : byte;
    begin
      i := 1;
      link_node_list_start(list_of_inter_res, p_nd_list);
      while p_nd_list <> nil do
        begin
          write(i, ') ', complex_to_string(p_nd_list^.data), ' ');
          p_nd_list := p_nd_list^.link;
          i += 1;
        end;
    end;

  {* В зависимости от строкового представления оператора по указателю p_opr, 
   * к операндам вычисляемого выражения expres применяется тот или иной оператор}
  procedure process_operator(var expres : t_calculated_RPN_expression; const p_opr : t_p_string);
    var p_comp1, p_comp2, p_res : t_p_complex;
    begin
      new(p_res);
      take_operands(expres.st, p_comp1, p_comp2, p_opr);
      case p_opr^ of
        '+' : addition(p_comp1, p_comp2, p_res);
        '-' : subtraction(p_comp1, p_comp2, p_res);
        '*' : multiplication(p_comp1, p_comp2, p_res);
        '/' : division(p_comp1, p_comp2, p_res);
        '~' : unary_minus(p_comp1, p_res);
        'ln' : natural_logarithm(p_comp1, p_res);
      end;
      push(expres.st, p_res);
      push_last(expres.inter_res, p_res);
    end;

  {* Присваивает указателю p_complex указатель на значение переменной, хранящейся в ячейке по указателю p_cell}
  procedure take_variable_value_from_cell(const p_cell : t_p_cell; var p_complex : t_p_complex);
    var p_var : t_p_variable;
    begin
      p_var := p_cell^.data;
      p_complex := p_var^.value;
    end;

  {* В зависимости от типа ячейки по указателю p_cell: opr, con или var вычисляемого выражения expres происходит:
   * обработка оператора; или добавление указателя на константу в стек вычисляемого выражения expres;
   * или добавление указателя на значение переменной в стек вычисляемого выражения expres}
  procedure process_cell(var expres : t_calculated_RPN_expression; const p_cell : t_p_cell);
    var pt : pointer;
    begin
      case p_cell^.type_c of
        'opr' : process_operator(expres, p_cell^.data);
        'con' : begin
                  pt := p_cell^.data;
                  push(expres.st, pt);
                end;  
        'var' : begin
                  take_variable_value_from_cell(p_cell, pt);
                  push(expres.st, pt);
                end;
      end;
    end;

  {* Возвращает результат вычисления вычисляемого выражения expres в виде строки. Выводит промежуточные результаты вычисления в консоль}
  function calculate_expres(var expres : t_calculated_RPN_expression) : string;
    var res : string;
        p_cell : t_p_cell;
        p_node : t_p_node;
    begin
      link_node_list_start(expres.expres, p_node);
      repeat
        take_implicitly_element(p_node, p_cell);
        process_cell(expres, p_cell);
      until p_node = nil;
      res := complex_to_string(expres.st.head^.data);
      print_inter_results(expres.inter_res);
      writeln;
      clear_list(expres.inter_res, sizeof(t_complex));
      calculate_expres := res; 
    end; 

  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}
  {@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}

  {* Возвращает значение "истина", если в вычисляемом выражении expres есть переменные. Иначе - возвращает значение "ложь"}
  function is_have_variables(const expres : t_calculated_RPN_expression) : boolean;
    begin
      is_have_variables := expres.variables.start <> nil;
    end;

  var s1, s2 : string;
      expres : t_calculated_RPN_expression;
      i : byte;

  begin
    writeln('Выражение должно состоять из констант, знаков операций и переменных');
    writeln('Константы могут быть комплексными');
    writeln('Внимание! Зарезервированные имена переменных, которые нельзя применять: i');
    writeln;

    writeln('Пожалуйста, используйте имена переменных длинной: ', MAX_VARIABLE_NAME_LENGTH);
    writeln('Разделяйте пробелами все, кроме комплексных констант. Пример: - a + b * 34+2i + 1i');
    writeln('Не пропускайте, пожалуйста, знаков операций и цифр в выражении. Записи вида: "3x", "i" недопустимы.');

    write('В комплексной константе, имеющей как действительную, так и мнимую часть, вы можете выбрать знак только для мнимой, ');
    write('действительная часть обязана быть всегда положительной. Пример "3+2i", "3-2i" ');

    writeln('Пример допустимого выражения: 1i + 2+3i + 2-3i - a - * ( 3 - ( - 2 ) )');
    writeln('Примеры недопустимых записей: "-2", "-2+2i", "-3i", "(3+2+4*9)"');
    writeln;

    writeln('-----------');
    write('Доступные операторы: ');
    for i := 1 to NUM_OF_OP do
      write(OPERATORS.op_s[i], ' ');
    writeln;
    writeln('-----------');

    write('Введите выражение: ');
    readln(s1);

    s2 := trans_expression_to_RPN(s1);
    write('Преобразованное выражение: ');
    writeln(s2);

    writeln('--------------------');
    string_into_calculated(s2, expres);

    if is_have_variables(expres) then
      while True do
        begin
          read_variables(expres);
          writeln(calculate_expres(expres));
        end
    else
      writeln(calculate_expres(expres));
  end.