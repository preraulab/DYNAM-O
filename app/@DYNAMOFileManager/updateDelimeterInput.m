function updateDelimeterInput(app)
    % updateDelimeterInput  Convert the delimiter dropdown selection to a format character.
    %
    %   Maps the human-readable dropdown value (Comma/Tab/Space/Semicolon)
    %   to the actual delimiter character stored in app.delimeter.

    switch app.DelimeterOptionField.Value
        case 'Comma',     app.delimeter = ',';
        case 'Tab',       app.delimeter = '\t';
        case 'Space',     app.delimeter = ' ';
        case 'Semicolon', app.delimeter = ';';
    end
end
